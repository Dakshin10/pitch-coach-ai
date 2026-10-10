"""Feedback endpoint: POST /feedback."""
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from google.cloud import firestore as fs

from auth.dependencies import get_current_user_optional
from firestore import get_db
from models import FEEDBACK_COL, User
from schemas import FeedbackRequest, FeedbackResponse
from utils.sanitizer import remove_emojis

router = APIRouter(tags=["feedback"])


@router.post("/feedback", response_model=FeedbackResponse)
def submit_feedback(
    req: FeedbackRequest,
    current_user: User | None = Depends(get_current_user_optional),
    db: fs.Client = Depends(get_db),
):
    feedback_id = str(uuid.uuid4())
    doc = {
        "id": feedback_id,
        "user_id": current_user.id if current_user else "anonymous",
        "category": req.category,
        "message": remove_emojis(req.message),
        "screenshot_base64": req.screenshot_base64,
        "app_version": req.app_version,
        "device_info": req.device_info if req.include_device_info else None,
        "created_at": datetime.now(timezone.utc),
    }
    db.collection(FEEDBACK_COL).document(feedback_id).set(doc)
    return FeedbackResponse(
        status="success",
        id=feedback_id,
        message="Thank you for your feedback! We will review it shortly.",
    )
