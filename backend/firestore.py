"""
Firebase Admin SDK initialisation and Firestore client singleton.

Collections used:
  users/          — user documents  (doc id = user_id)
  sessions/       — practice session documents
  achievements/   — achievement documents

Recordings live in Firebase Storage under audio/<user_id>/<session_id>.<ext>.
"""
import firebase_admin
from firebase_admin import credentials, firestore, storage
from config import get_settings

_app: firebase_admin.App | None = None


def _init_app() -> None:
    global _app
    if _app is not None:
        return
    settings = get_settings()
    cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    options = {"storageBucket": settings.FIREBASE_STORAGE_BUCKET} if settings.FIREBASE_STORAGE_BUCKET else None
    _app = firebase_admin.initialize_app(cred, options)


def get_db() -> firestore.Client:
    """FastAPI dependency — returns a Firestore client (thread-safe singleton)."""
    _init_app()
    return firestore.client()


def get_bucket():
    """Returns the default Firebase Storage bucket (audio recordings)."""
    _init_app()
    if not get_settings().FIREBASE_STORAGE_BUCKET:
        raise RuntimeError("FIREBASE_STORAGE_BUCKET is not set in backend/.env")
    return storage.bucket()
