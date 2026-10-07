"""Storage layer for slide decks: Firestore persistence with local disk image cache."""
import json
import logging
import os
import shutil
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional

from config import get_settings
from firestore import get_db
from models import SlideDeck, SLIDE_DECKS_COL

logger = logging.getLogger(__name__)


class DeckStore:
    """Manages slide deck persistence across Firestore and local storage."""

    def __init__(self):
        self.settings = get_settings()
        self.base_dir = self.settings.SLIDE_DECK_DIR
        os.makedirs(self.base_dir, exist_ok=True)
        # In-memory lookup for hot status updates
        self._memory_cache: Dict[str, SlideDeck] = {}

    def get_deck_dir(self, deck_id: str) -> str:
        d = os.path.join(self.base_dir, deck_id)
        os.makedirs(d, exist_ok=True)
        return d

    def get_slides_dir(self, deck_id: str) -> str:
        d = os.path.join(self.get_deck_dir(deck_id), "slides")
        os.makedirs(d, exist_ok=True)
        return d

    def get_slide_image_path(self, deck_id: str, slide_number: int) -> str:
        return os.path.join(self.get_slides_dir(deck_id), f"slide_{slide_number}.jpg")

    def save(self, deck: SlideDeck) -> None:
        """Persist to memory, local metadata.json, and Firestore."""
        deck.updated_at = datetime.now(timezone.utc)
        self._memory_cache[deck.id] = deck

        # 1. Local backup JSON
        try:
            deck_dir = self.get_deck_dir(deck.id)
            meta_path = os.path.join(deck_dir, "metadata.json")
            with open(meta_path, "w", encoding="utf-8") as f:
                d = deck.to_dict()
                # Format datetimes for JSON serialization
                d["created_at"] = deck.created_at.isoformat()
                d["updated_at"] = deck.updated_at.isoformat()
                json.dump(d, f, indent=2)
        except Exception as e:
            logger.warning("Could not save local deck metadata for %s: %s", deck.id, e)

        # 2. Firestore document
        try:
            db = get_db()
            db.collection(SLIDE_DECKS_COL).document(deck.id).set(deck.to_dict())
        except Exception as e:
            logger.warning("Firestore save failed for deck %s (using local cache): %s", deck.id, e)

    def get(self, deck_id: str) -> Optional[SlideDeck]:
        """Fetch deck by ID from memory, Firestore, or disk."""
        # 1. Memory cache
        if deck_id in self._memory_cache:
            return self._memory_cache[deck_id]

        # 2. Firestore
        try:
            db = get_db()
            doc = db.collection(SLIDE_DECKS_COL).document(deck_id).get()
            if doc.exists:
                deck = SlideDeck.from_dict(doc.to_dict())
                self._memory_cache[deck_id] = deck
                return deck
        except Exception as e:
            logger.warning("Firestore get failed for deck %s: %s", deck_id, e)

        # 3. Local disk fallback
        try:
            meta_path = os.path.join(self.base_dir, deck_id, "metadata.json")
            if os.path.exists(meta_path):
                with open(meta_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data.get("created_at"), str):
                        data["created_at"] = datetime.fromisoformat(data["created_at"])
                    if isinstance(data.get("updated_at"), str):
                        data["updated_at"] = datetime.fromisoformat(data["updated_at"])
                    deck = SlideDeck.from_dict(data)
                    self._memory_cache[deck_id] = deck
                    return deck
        except Exception as e:
            logger.warning("Disk fallback load failed for deck %s: %s", deck_id, e)

        return None

    def find_by_hash(self, user_id: str, content_hash: str) -> Optional[SlideDeck]:
        """Find an already-completed deck by user_id and SHA-256 hash."""
        # Memory check
        for deck in self._memory_cache.values():
            if deck.user_id == user_id and deck.content_hash == content_hash and deck.status == "done":
                return deck

        # Firestore check
        try:
            db = get_db()
            docs = (
                db.collection(SLIDE_DECKS_COL)
                .where("user_id", "==", user_id)
                .where("content_hash", "==", content_hash)
                .where("status", "==", "done")
                .limit(1)
                .stream()
            )
            for doc in docs:
                deck = SlideDeck.from_dict(doc.to_dict())
                self._memory_cache[deck.id] = deck
                return deck
        except Exception as e:
            logger.warning("Firestore query by hash failed: %s", e)

        return None

    def list_user_decks(self, user_id: str) -> List[SlideDeck]:
        """List all slide decks for a user."""
        decks = []
        try:
            db = get_db()
            docs = (
                db.collection(SLIDE_DECKS_COL)
                .where("user_id", "==", user_id)
                .stream()
            )
            for doc in docs:
                decks.append(SlideDeck.from_dict(doc.to_dict()))
        except Exception as e:
            logger.warning("Firestore list_user_decks failed: %s", e)

        # Fallback to local memory if firestore failed or returned empty
        if not decks:
            decks = [d for d in self._memory_cache.values() if d.user_id == user_id]

        decks.sort(key=lambda d: d.created_at, reverse=True)
        return decks

    def delete(self, deck_id: str) -> bool:
        """Delete from memory, Firestore, and local files."""
        self._memory_cache.pop(deck_id, None)

        # Remove local disk files
        try:
            deck_dir = os.path.join(self.base_dir, deck_id)
            if os.path.exists(deck_dir):
                shutil.rmtree(deck_dir, ignore_errors=True)
        except Exception as e:
            logger.warning("Failed to delete local dir for deck %s: %s", deck_id, e)

        # Remove Firestore doc
        try:
            db = get_db()
            db.collection(SLIDE_DECKS_COL).document(deck_id).delete()
            return True
        except Exception as e:
            logger.warning("Firestore delete failed for deck %s: %s", deck_id, e)
            return False

    def cleanup_expired(self, ttl_days: Optional[int] = None) -> int:
        """Delete decks older than TTL days."""
        ttl = ttl_days or self.settings.SLIDE_DECK_TTL_DAYS
        cutoff = datetime.now(timezone.utc) - timedelta(days=ttl)
        deleted_count = 0

        # Scan local directories
        if os.path.exists(self.base_dir):
            for deck_id in os.listdir(self.base_dir):
                deck = self.get(deck_id)
                if deck and deck.created_at < cutoff:
                    self.delete(deck_id)
                    deleted_count += 1

        return deleted_count


# Singleton instance
deck_store = DeckStore()
