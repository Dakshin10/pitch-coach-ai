"""Password hashing and JWT token utilities using PyJWT and bcrypt."""
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt

from config import get_settings

settings = get_settings()


def hash_password(plain: str) -> str:
    """Hashes a plaintext password using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Verifies a plaintext password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def _encode(data: dict, expire_delta: timedelta) -> str:
    payload = {**data, "exp": datetime.now(timezone.utc) + expire_delta}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_access_token(data: dict) -> str:
    return _encode(
        {**data, "type": "access"},
        timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )


def create_refresh_token(data: dict) -> str:
    return _encode(
        {**data, "type": "refresh"},
        timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


def decode_token(token: str) -> Optional[dict]:
    """Decodes and validates a JWT token using PyJWT."""
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except (jwt.PyJWTError, Exception):
        return None
