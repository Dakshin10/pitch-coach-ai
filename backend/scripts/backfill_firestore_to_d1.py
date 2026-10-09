"""Idempotent and resumable backfill script from Firestore sessions to Cloudflare D1.

Reads analyzed sessions from Firestore and upserts them into D1 session_metrics and session_fillers.
Supports checkpointing, resumption via --start-after, and batching.

Usage:
    python scripts/backfill_firestore_to_d1.py [--batch-size 50] [--start-after <doc_id>] [--dry-run]
"""
import argparse
from datetime import datetime, timezone
import logging
import os
import sys
from typing import Optional, Tuple

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from d1.d1_client import get_d1_client
from d1.sync import build_d1_upsert_statements
from firestore import get_db
from models import SESSIONS_COL

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("backfill_firestore_to_d1")

CHECKPOINT_FILE = os.path.join(backend_dir, ".d1_backfill_checkpoint")


def load_checkpoint() -> Optional[str]:
    if os.path.exists(CHECKPOINT_FILE):
        try:
            with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
                return f.read().strip() or None
        except Exception:
            pass
    return None


def save_checkpoint(doc_id: str) -> None:
    try:
        with open(CHECKPOINT_FILE, "w", encoding="utf-8") as f:
            f.write(doc_id)
    except Exception as exc:
        logger.warning("Could not write checkpoint file: %s", exc)


def backfill_firestore_to_d1(
    batch_size: int = 50,
    start_after: Optional[str] = None,
    dry_run: bool = False,
    user_id: Optional[str] = None,
    limit: Optional[int] = None,
) -> Tuple[int, int]:
    """Transfers sessions from Firestore to D1.

    Returns (scanned_count, synced_count).
    """
    db = get_db()
    if db is None:
        logger.error("Firestore DB connection unavailable.")
        return 0, 0

    d1 = get_d1_client()
    if not dry_run and not d1.is_configured:
        logger.error("D1 client not configured. Set CF_ACCOUNT_ID, CF_D1_DATABASE_ID, and CF_API_TOKEN in .env.")
        return 0, 0

    query = db.collection(SESSIONS_COL).order_by("__name__")
    if user_id:
        query = query.where("user_id", "==", user_id)

    checkpoint = start_after or load_checkpoint()
    if checkpoint:
        logger.info("Resuming backfill starting after doc id: %s", checkpoint)
        last_doc_snapshot = db.collection(SESSIONS_COL).document(checkpoint).get()
        if last_doc_snapshot.exists:
            query = query.start_after(last_doc_snapshot)

    if limit:
        query = query.limit(limit)

    total_scanned = 0
    total_synced = 0
    current_statements = []
    current_doc_ids = []

    logger.info("Starting Firestore -> D1 backfill (batch_size=%d, dry_run=%s)...", batch_size, dry_run)

    for doc in query.stream():
        total_scanned += 1
        data = doc.to_dict() or {}
        doc_id = doc.id
        data["id"] = data.get("id") or doc_id

        # We only backfill analyzed sessions or sessions with metrics
        if not data.get("is_analyzed") and not data.get("metrics"):
            continue

        stmts = build_d1_upsert_statements(data)
        current_statements.extend(stmts)
        current_doc_ids.append(doc_id)

        if len(current_doc_ids) >= batch_size:
            if not dry_run:
                d1.batch(current_statements)
                for did in current_doc_ids:
                    db.collection(SESSIONS_COL).document(did).update({"d1_pending": False})
                save_checkpoint(current_doc_ids[-1])
            total_synced += len(current_doc_ids)
            logger.info("Synced batch of %d sessions to D1 (total synced: %d)", len(current_doc_ids), total_synced)
            current_statements = []
            current_doc_ids = []

    if current_doc_ids:
        if not dry_run:
            d1.batch(current_statements)
            for did in current_doc_ids:
                db.collection(SESSIONS_COL).document(did).update({"d1_pending": False})
            save_checkpoint(current_doc_ids[-1])
        total_synced += len(current_doc_ids)
        logger.info("Synced final batch of %d sessions to D1 (total synced: %d)", len(current_doc_ids), total_synced)

    logger.info(
        "Firestore -> D1 backfill completed. Scanned: %d, Synced: %d (dry_run=%s)",
        total_scanned,
        total_synced,
        dry_run,
    )
    return total_scanned, total_synced


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backfill Firestore sessions into Cloudflare D1.")
    parser.add_argument("--batch-size", type=int, default=50, help="Batch size for D1 batch statements")
    parser.add_argument("--start-after", type=str, default=None, help="Resume backfill after this session doc ID")
    parser.add_argument("--user-id", type=str, default=None, help="Optional user_id filter")
    parser.add_argument("--limit", type=int, default=None, help="Max number of sessions to scan")
    parser.add_argument("--dry-run", action="store_true", help="Scan and construct statements without writing to D1")
    args = parser.parse_args()

    backfill_firestore_to_d1(
        batch_size=args.batch_size,
        start_after=args.start_after,
        dry_run=args.dry_run,
        user_id=args.user_id,
        limit=args.limit,
    )
