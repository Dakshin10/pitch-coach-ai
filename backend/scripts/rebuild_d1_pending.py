"""Script/job that queries Firestore for docs with d1_pending=true and rebuilds/upserts them into D1.

Usage:
    python scripts/rebuild_d1_pending.py [--dry-run]
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
logger = logging.getLogger("rebuild_d1_pending")


def rebuild_pending_sessions(dry_run: bool = False, limit: int = 100) -> Tuple[int, int, int]:
    """Finds all sessions where d1_pending == True, syncs them to D1, and clears d1_pending.

    Returns (total_found, total_succeeded, total_failed).
    """
    db = get_db()
    if db is None:
        logger.error("Firestore DB connection unavailable.")
        return 0, 0, 0

    d1 = get_d1_client()
    if not dry_run and not d1.is_configured:
        logger.warning("Cloudflare D1 is not configured. Cannot process pending syncs.")
        return 0, 0, 0

    query = db.collection(SESSIONS_COL).where("d1_pending", "==", True).limit(limit)

    total_found = 0
    total_succeeded = 0
    total_failed = 0

    logger.info("Scanning Firestore for d1_pending=True sessions...")

    for doc in query.stream():
        total_found += 1
        data = doc.to_dict() or {}
        data["id"] = data.get("id") or doc.id
        doc_id = doc.id

        logger.info("Processing pending doc %s...", doc_id)
        if dry_run:
            total_succeeded += 1
            continue

        ok = upsert_session_to_d1(data, d1_client=d1)
        if ok:
            total_succeeded += 1
            try:
                db.collection(SESSIONS_COL).document(doc_id).update({"d1_pending": False})
                logger.info("Successfully synced doc %s to D1 and cleared d1_pending.", doc_id)
            except Exception as exc:
                logger.warning("Failed to clear d1_pending on doc %s: %s", doc_id, exc)
        else:
            total_failed += 1
            logger.warning("Failed to sync pending doc %s to D1.", doc_id)

    logger.info(
        "Pending rebuild completed. Found: %d, Succeeded: %d, Failed: %d (dry_run=%s)",
        total_found,
        total_succeeded,
        total_failed,
        dry_run,
    )
    return total_found, total_succeeded, total_failed


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rebuild D1 rows for Firestore docs where d1_pending=true.")
    parser.add_argument("--dry-run", action="store_true", help="Find pending docs without syncing")
    parser.add_argument("--limit", type=int, default=100, help="Maximum number of pending docs to process")
    args = parser.parse_args()

    rebuild_pending_sessions(dry_run=args.dry_run, limit=args.limit)
