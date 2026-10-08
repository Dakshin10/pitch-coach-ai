"""Maintenance script to purge expired guest accounts, orphaned slide decks, and expired sessions."""
import logging
import os
import sys
from datetime import datetime, timezone, timedelta

# Add backend directory to sys.path so modules can be imported directly
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from config import get_settings
from firestore import get_db
from models import (
    ACHIEVEMENTS_COL,
    SESSIONS_COL,
    SLIDE_DECKS_COL,
    USERS_COL,
    User,
)
from slides.store import deck_store

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


def purge_expired_guests() -> int:
    """Finds and permanently deletes expired guest accounts and their associated resources."""
    settings = get_settings()
    db = get_db()
    if db is None:
        logger.warning("Firestore client unavailable. Skipping guest purge.")
        return 0

    now = datetime.now(timezone.utc)
    deleted_users_count = 0
    deleted_sessions_count = 0
    deleted_decks_count = 0

    try:
        users_stream = db.collection(USERS_COL).where("is_guest", "==", True).stream()
        for doc in users_stream:
            user = User.from_dict(doc.to_dict())
            expiry = user.expires_at or (user.created_at + timedelta(days=settings.GUEST_EXPIRE_DAYS))
            if now > expiry:
                user_id = user.id
                logger.info("Purging expired guest user: %s (expired at %s)", user_id, expiry)

                # 1. Delete user slide decks
                user_decks = deck_store.list_user_decks(user_id)
                for d in user_decks:
                    deck_store.delete(d.id)
                    deleted_decks_count += 1

                # 2. Delete user sessions
                sessions = db.collection(SESSIONS_COL).where("user_id", "==", user_id).stream()
                for s in sessions:
                    db.collection(SESSIONS_COL).document(s.id).delete()
                    deleted_sessions_count += 1

                # 3. Delete achievements
                achievements = db.collection(ACHIEVEMENTS_COL).where("user_id", "==", user_id).stream()
                for a in achievements:
                    db.collection(ACHIEVEMENTS_COL).document(a.id).delete()

                # 4. Delete user doc
                db.collection(USERS_COL).document(user_id).delete()
                deleted_users_count += 1

    except Exception as exc:
        logger.error("Error during guest purge: %s", exc)

    logger.info(
        "Purged %d expired guest users, %d sessions, and %d slide decks",
        deleted_users_count,
        deleted_sessions_count,
        deleted_decks_count,
    )
    return deleted_users_count


def purge_expired_slide_decks() -> int:
    """Deletes slide decks older than TTL."""
    cleaned = deck_store.cleanup_expired()
    logger.info("Purged %d expired slide decks via TTL cleanup", cleaned)
    return cleaned


def main():
    logger.info("Starting maintenance cleanup...")
    purged_guests = purge_expired_guests()
    purged_decks = purge_expired_slide_decks()
    logger.info(
        "Maintenance cleanup finished successfully. Purged guests: %d, Purged decks: %d",
        purged_guests,
        purged_decks,
    )


if __name__ == "__main__":
    main()
