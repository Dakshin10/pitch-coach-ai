"""Daily quota management using Firestore user_quotas collection."""
import logging
from datetime import datetime, timezone
from fastapi import HTTPException, status
from firestore import get_db

logger = logging.getLogger(__name__)


def check_and_increment_daily_quota(user_id: str, feature: str, limit: int) -> int:
    """
    Checks and increments daily usage counter for a user and feature.
    Throws HTTP 429 if limit is exceeded.
    Returns the new counter value.
    """
    if limit <= 0:
        return 0
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    doc_id = f"{user_id}_{feature}_{today_str}"

    db = get_db()
    if db is None:
        return 0

    try:
        doc_ref = db.collection("user_quotas").document(doc_id)
        doc = doc_ref.get()
        current_count = doc.to_dict().get("count", 0) if doc.exists else 0

        if current_count >= limit:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Daily quota exceeded: you have reached the maximum of {limit} {feature} per day.",
            )

        new_count = current_count + 1
        doc_ref.set({
            "user_id": user_id,
            "feature": feature,
            "date": today_str,
            "count": new_count,
            "updated_at": datetime.now(timezone.utc),
        })
        return new_count
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Could not update daily quota for %s (%s): %s", user_id, feature, exc)
        return 0
