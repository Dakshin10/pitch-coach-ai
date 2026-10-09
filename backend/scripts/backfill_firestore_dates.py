"""One-off backfill script to ensure every Firestore session document has local_date and tz_offset_minutes.

Usage:
    python scripts/backfill_firestore_dates.py [--default-tz 330] [--dry-run] [--force]
"""
import argparse
from datetime import datetime, timezone, timedelta
import logging
import os
import sys
from typing import Any, Dict, Optional, Tuple

# Add backend directory to sys.path so modules can be imported directly
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from firestore import get_db
from models import SESSIONS_COL

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("backfill_firestore_dates")


def _parse_created_at(val: Any) -> datetime:
    """Parse a created_at field which could be a Firestore Timestamp, datetime, or ISO string."""
    if val is None:
        return datetime.now(timezone.utc)
    if isinstance(val, datetime):
        if val.tzinfo is None:
            return val.replace(tzinfo=timezone.utc)
        return val.astimezone(timezone.utc)
    if hasattr(val, "to_datetime"):  # Firestore Timestamp
        dt = val.to_datetime()
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    if isinstance(val, str):
        try:
            # Handle ISO string e.g. 2026-10-09T17:00:00Z or +00:00
            iso_str = val.replace("Z", "+00:00")
            dt = datetime.fromisoformat(iso_str)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc)
        except Exception:
            pass
    return datetime.now(timezone.utc)


def compute_fields_to_update(
    doc_data: Dict[str, Any],
    default_tz: int = 330,
    force: bool = False,
) -> Optional[Dict[str, Any]]:
    """Determines what fields need updating for a session doc. Returns None if already complete."""
    updates: Dict[str, Any] = {}

    existing_local_date = doc_data.get("local_date")
    existing_tz = doc_data.get("tz_offset_minutes")

    # Determine tz_offset_minutes to use
    tz_offset = default_tz if force else (existing_tz if existing_tz is not None else default_tz)

    # If missing or force, compute local_date
    created_at_utc = _parse_created_at(doc_data.get("created_at"))
    computed_local_date = (created_at_utc + timedelta(minutes=tz_offset)).strftime("%Y-%m-%d")

    needs_date_update = force or (existing_local_date is None or not str(existing_local_date).strip())
    needs_tz_update = force or (existing_tz is None)

    if needs_date_update:
        updates["local_date"] = computed_local_date
    if needs_tz_update:
        updates["tz_offset_minutes"] = tz_offset

    # Also backfill metrics snapshot and stage if missing
    if "metrics" not in doc_data and doc_data.get("is_analyzed"):
        updates["metrics"] = {
            "wpm": float(doc_data.get("wpm", 0.0) or 0.0),
            "overall": float(doc_data.get("overall_score", 0.0) or 0.0),
            "clarity": float(doc_data.get("clarity_score", 0.0) or 0.0),
            "confidence": float(doc_data.get("confidence_score", 0.0) or 0.0),
            "pause_count": int(doc_data.get("pause_count", 0) or 0),
            "duration": float(doc_data.get("duration_seconds", 0.0) or 0.0),
            "filler_count": int(doc_data.get("filler_word_count", 0) or 0),
        }
    if "stage" not in doc_data:
        updates["stage"] = "done" if doc_data.get("is_analyzed") else "pending"

    return updates if updates else None


def backfill_sessions(
    default_tz: int = 330,
    batch_size: int = 200,
    dry_run: bool = False,
    force: bool = False,
    limit: Optional[int] = None,
) -> Tuple[int, int]:
    """Iterates through all sessions and backfills local_date and tz_offset_minutes.

    Returns (total_scanned, total_updated).
    """
    db = get_db()
    if db is None:
        logger.error("Firestore DB connection unavailable.")
        return 0, 0

    query = db.collection(SESSIONS_COL)
    if limit:
        query = query.limit(limit)

    total_scanned = 0
    total_updated = 0
    batch = db.batch()
    batch_ops = 0

    logger.info(
        "Starting Firestore session backfill (default_tz=%d, dry_run=%s, force=%s)...",
        default_tz,
        dry_run,
        force,
    )

    for doc in query.stream():
        total_scanned += 1
        data = doc.to_dict() or {}
        updates = compute_fields_to_update(data, default_tz=default_tz, force=force)

        if updates:
            total_updated += 1
            logger.info("Doc %s needs updates: %s", doc.id, updates)
            if not dry_run:
                batch.update(doc.reference, updates)
                batch_ops += 1

                if batch_ops >= batch_size:
                    batch.commit()
                    logger.info("Committed batch of %d updates.", batch_ops)
                    batch = db.batch()
                    batch_ops = 0

    if not dry_run and batch_ops > 0:
        batch.commit()
        logger.info("Committed final batch of %d updates.", batch_ops)

    logger.info(
        "Backfill finished. Total scanned: %d, Total updated: %d (dry_run=%s)",
        total_scanned,
        total_updated,
        dry_run,
    )
    return total_scanned, total_updated


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backfill local_date and tz_offset_minutes on Firestore sessions.")
    default_env_tz = int(os.getenv("DEFAULT_TZ_OFFSET_MINUTES", "330"))
    parser.add_argument(
        "--default-tz",
        type=int,
        default=default_env_tz,
        help="Default timezone offset in minutes when unknown (default: 330 for IST, configurable)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=200,
        help="Firestore write batch size (max 500)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Inspect documents without writing updates",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Recalculate and update even if fields are already present",
    )
    args = parser.parse_args()

    backfill_sessions(
        default_tz=args.default_tz,
        batch_size=args.batch_size,
        dry_run=args.dry_run,
        force=args.force,
    )
