"""Nightly reconciliation job: rebuild missing D1 rows from Firestore metrics snapshot.

Usage:
    python scripts/nightly_rebuild_missing_d1.py [--dry-run]
"""
import argparse
import logging
import os
import sys
from typing import Tuple

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from d1.d1_client import get_d1_client
from d1.sync import upsert_session_to_d1
from firestore import get_db
from models import SESSIONS_COL

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("nightly_rebuild_missing_d1")


def rebuild_missing_d1_rows(dry_run: bool = False) -> Tuple[int, int, int]:
    """Finds missing or pending D1 sessions from Firestore documents and rebuilds them.

    Returns: (total_scanned, total_rebuilt, total_failed)
    """
    db = get_db()
    if db is None:
        logger.error("[nightly] Firestore unavailable.")
        return 0, 0, 0

    d1 = get_d1_client()
    if not dry_run and not d1.is_configured:
        logger.warning("[nightly] Cloudflare D1 not configured.")
        return 0, 0, 0

    logger.info("[nightly] Starting reconciliation of Firestore sessions -> D1...")

    # Fetch all existing session IDs in D1
    d1_ids = set()
    if d1.is_configured:
        try:
            rows = d1.query("SELECT id FROM session_metrics WHERE deleted_at IS NULL;")
            d1_ids = {r["id"] for r in rows}
            logger.info("[nightly] Found %d active sessions in D1.", len(d1_ids))
        except Exception as exc:
            logger.error("[nightly] Failed to fetch D1 session IDs: %s", exc)

    total_scanned = 0
    total_rebuilt = 0
    total_failed = 0

    # Stream all Firestore sessions
    sessions_stream = db.collection(SESSIONS_COL).stream()

    for doc in sessions_stream:
        total_scanned += 1
        data = doc.to_dict() or {}
        session_id = data.get("id") or doc.id
        data["id"] = session_id
        is_pending = data.get("d1_pending", False)
        is_missing_in_d1 = session_id not in d1_ids

        # Rebuild if pending or missing in D1
        if is_pending or is_missing_in_d1:
            logger.info(
                "[nightly] Rebuilding session %s (missing_in_d1=%s, pending=%s)",
                session_id,
                is_missing_in_d1,
                is_pending,
            )

            if dry_run:
                total_rebuilt += 1
                continue

            try:
                # Reconstruct from immutable metrics snapshot if flat metrics missing
                if "metrics" in data and isinstance(data["metrics"], dict):
                    m = data["metrics"]
                    if "wpm" not in data or data.get("wpm") is None:
                        data["wpm"] = m.get("wpm", 0.0)
                    if "overall_score" not in data or data.get("overall_score") is None:
                        data["overall_score"] = m.get("overall", 0.0)
                    if "clarity_score" not in data or data.get("clarity_score") is None:
                        data["clarity_score"] = m.get("clarity", 0.0)
                    if "confidence_score" not in data or data.get("confidence_score") is None:
                        data["confidence_score"] = m.get("confidence", 0.0)
                    if "duration_seconds" not in data or data.get("duration_seconds") is None:
                        data["duration_seconds"] = m.get("duration", 0.0)

                ok = upsert_session_to_d1(data, d1_client=d1)
                if ok:
                    total_rebuilt += 1
                    if is_pending:
                        doc.reference.update({"d1_pending": False})
                else:
                    total_failed += 1
            except Exception as exc:
                logger.error("[nightly] Failed to rebuild session %s: %s", session_id, exc)
                total_failed += 1

    logger.info(
        "[nightly] Reconciliation completed. Scanned: %d, Rebuilt: %d, Failed: %d (dry_run=%s)",
        total_scanned,
        total_rebuilt,
        total_failed,
        dry_run,
    )
    return total_scanned, total_rebuilt, total_failed


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Nightly rebuild of missing D1 rows from Firestore.")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without making changes.")
    args = parser.parse_args()

    rebuild_missing_d1_rows(dry_run=args.dry_run)
