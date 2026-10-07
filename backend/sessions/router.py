"""Session CRUD routes: start, finish (upload + async pipeline), get, list."""
import os
import tempfile
import uuid
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.concurrency import run_in_threadpool
from google.cloud import firestore as fs

from auth.dependencies import get_current_user
from config import get_groq_key, get_settings
from firestore import get_bucket, get_db
from models import PracticeSession, User, SESSIONS_COL
from schemas import (
    FeedbackItem,
    SessionResult,
    SessionSummary,
    StartSessionRequest,
    StartSessionResponse,
)
from sessions.pipeline import analyze_audio

router = APIRouter(prefix="/sessions", tags=["sessions"])
settings = get_settings()

_ALLOWED_AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".webm", ".ogg", ".aac"}


import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _to_result(s: PracticeSession) -> SessionResult:
    feedback = []
    for item in (s.ai_feedback or []):
        if isinstance(item, dict):
            feedback.append(FeedbackItem(
                category=item.get("category", "clarity"),
                message=item.get("message", ""),
                severity=item.get("severity", "tip"),
                example=item.get("example"),
            ))
    return SessionResult(
        id=s.id,
        mode=s.mode,
        topic_or_question=s.topic_or_question,
        duration_seconds=s.duration_seconds or 0.0,
        transcript=s.transcript,
        wpm=s.wpm or 0.0,
        filler_word_count=s.filler_word_count or 0,
        filler_word_breakdown=s.filler_word_breakdown or {},
        pause_count=s.pause_count or 0,
        avg_pause_length=s.avg_pause_length or 0.0,
        clarity_score=s.clarity_score or 0.0,
        confidence_score=s.confidence_score or 0.0,
        overall_score=s.overall_score or 0.0,
        ai_feedback=feedback,
        created_at=s.created_at,
        is_analyzed=s.is_analyzed,
        analysis_failed=s.analysis_failed,
        failure_reason=s.failure_reason,
    )


def _to_summary(s: PracticeSession) -> SessionSummary:
    return SessionSummary(
        id=s.id,
        mode=s.mode,
        topic_or_question=s.topic_or_question,
        duration_seconds=s.duration_seconds or 0.0,
        overall_score=s.overall_score or 0.0,
        confidence_score=s.confidence_score or 0.0,
        created_at=s.created_at,
        is_analyzed=s.is_analyzed,
        analysis_failed=s.analysis_failed,
        failure_reason=s.failure_reason,
    )


def _audio_exists(ref: Optional[str]) -> bool:
    """True if the stored audio reference (Storage path, or legacy local path) is readable."""
    if not ref:
        return False
    if os.path.exists(ref):  # legacy sessions saved to local disk
        return True
    try:
        return get_bucket().blob(ref).exists()
    except Exception:
        return False


def _fetch_audio(ref: str) -> tuple[str, bool]:
    """Returns (local_path, is_temp). Downloads from Storage when needed."""
    if os.path.exists(ref):
        return ref, False
    fd, tmp = tempfile.mkstemp(suffix=os.path.splitext(ref)[1] or ".m4a")
    os.close(fd)
    try:
        get_bucket().blob(ref).download_to_filename(tmp)
    except Exception:
        os.remove(tmp)
        raise
    return tmp, True


# ─────────────────────────────────────────────────────────────────────────────
# Background pipeline task
# ─────────────────────────────────────────────────────────────────────────────

def _run_pipeline_bg(
    session_id: str,
    audio_ref: str,
    duration: float,
    user_profile: dict,
) -> None:
    """Runs in a background thread (FastAPI BackgroundTasks)."""
    from firestore import get_db as _get_db  # local import avoids circular issues

    db = _get_db()
    local_path, is_temp = None, False
    try:
        doc_ref = db.collection(SESSIONS_COL).document(session_id)
        doc = doc_ref.get()
        if not doc.exists:
            return

        local_path, is_temp = _fetch_audio(audio_ref)
        analysis = analyze_audio(
            audio_path=local_path,
            duration_seconds=duration,
            user_profile=user_profile,
            groq_api_key=get_groq_key("audio"),
            whisper_model=settings.GROQ_WHISPER_MODEL,
            llm_model=settings.GROQ_LLM_MODEL,
        )

        doc_ref.update({
            "transcript": analysis.transcript,
            "wpm": analysis.wpm,
            "filler_word_count": analysis.filler.total_count,
            "filler_word_breakdown": analysis.filler.breakdown,
            "pause_count": analysis.pauses.count,
            "avg_pause_length": analysis.pauses.avg_length,
            "clarity_score": analysis.clarity_score,
            "confidence_score": analysis.confidence_score,
            "overall_score": analysis.overall_score,
            "duration_seconds": analysis.duration_seconds,
            "ai_feedback": [
                {
                    "category": f.category,
                    "message": f.message,
                    "severity": f.severity,
                    "example": f.example,
                }
                for f in analysis.ai_feedback
            ],
            "is_analyzed": True,
        })
        logger.info("[pipeline] Session %s analyzed OK. Score=%.1f", session_id, analysis.overall_score)

    except Exception as exc:
        logger.error("[pipeline] ERROR for session %s: %s", session_id, exc)
        # Stop the app polling, but flag the failure so stats ignore the zero scores
        try:
            db.collection(SESSIONS_COL).document(session_id).update({
                "is_analyzed": True,
                "analysis_failed": True,
                "failure_reason": str(exc),
            })
        except Exception:
            pass
    finally:
        if is_temp and local_path and os.path.exists(local_path):
            os.remove(local_path)


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

from quota import check_and_increment_daily_quota

@router.post("/start", response_model=StartSessionResponse)
def start_session(
    req: StartSessionRequest,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Creates a session document in Firestore and returns its ID."""
    check_and_increment_daily_quota(current_user.id, "sessions", settings.MAX_SESSIONS_PER_DAY)

    session = PracticeSession(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        mode=req.mode,
        topic_or_question=req.topic_or_question,
    )
    db.collection(SESSIONS_COL).document(session.id).set(session.to_dict())
    return StartSessionResponse(session_id=session.id)


@router.post("/{session_id}/finish", response_model=SessionResult)
async def finish_session(
    session_id: str,
    background_tasks: BackgroundTasks,
    audio_file: UploadFile = File(...),
    duration_seconds: float = Form(0.0),
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """
    Receives the recorded audio file, saves it to disk, then kicks off the
    AI pipeline in the background.  Returns the session doc immediately
    (is_analyzed=False); the Flutter app polls GET /{id} until is_analyzed=True.
    """
    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")

    session_data = doc.to_dict()
    if session_data.get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    # Validate, then upload the recording to Firebase Storage
    raw_name = audio_file.filename or "recording.m4a"
    ext = os.path.splitext(raw_name)[1].lower() or ".m4a"
    if ext not in _ALLOWED_AUDIO_EXTS:
        raise HTTPException(status_code=400, detail="Unsupported audio format")

    max_bytes = settings.MAX_AUDIO_UPLOAD_MB * 1024 * 1024
    content = await audio_file.read(max_bytes + 1)
    if len(content) > max_bytes:
        raise HTTPException(status_code=413, detail="Audio file is too large")
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    audio_ref = f"audio/{current_user.id}/{session_id}{ext}"
    try:
        await run_in_threadpool(
            lambda: get_bucket().blob(audio_ref).upload_from_string(
                content, content_type=audio_file.content_type or "audio/mp4"
            )
        )
    except Exception as exc:
        logger.error("[storage] upload failed for session %s: %s", session_id, exc)
        raise HTTPException(status_code=503, detail="Could not store the recording. Please try again.")

    doc_ref.update({
        "audio_url": audio_ref,
        "duration_seconds": duration_seconds,
    })

    # Kick off AI pipeline in background
    user_profile = {
        "feedback_style": current_user.feedback_style,
        "experience_level": current_user.experience_level,
    }
    background_tasks.add_task(
        _run_pipeline_bg, session_id, audio_ref, duration_seconds, user_profile
    )

    updated_doc = doc_ref.get()
    session = PracticeSession.from_dict(updated_doc.to_dict())
    return _to_result(session)


@router.post("/{session_id}/retry", response_model=SessionResult)
def retry_analysis(
    session_id: str,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Re-runs the AI pipeline on the already-uploaded audio of a failed session."""
    doc_ref = db.collection(SESSIONS_COL).document(session_id)
    doc = doc_ref.get()
    if not doc.exists or doc.to_dict().get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    data = doc.to_dict()
    if not data.get("analysis_failed"):
        raise HTTPException(status_code=400, detail="Session did not fail analysis")
    audio_ref = data.get("audio_url")
    if not _audio_exists(audio_ref):
        raise HTTPException(status_code=410, detail="Original recording is no longer available")

    doc_ref.update({"is_analyzed": False, "analysis_failed": False})
    background_tasks.add_task(
        _run_pipeline_bg,
        session_id,
        audio_ref,
        data.get("duration_seconds") or 0.0,
        {
            "feedback_style": current_user.feedback_style,
            "experience_level": current_user.experience_level,
        },
    )
    return _to_result(PracticeSession.from_dict(doc_ref.get().to_dict()))


def sweep_stuck_sessions(cutoff_seconds: int = 600) -> int:
    """Finds all sessions stuck in processing exceeding cutoff_seconds and marks them failed."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=cutoff_seconds)
    db = get_db()
    count = 0
    if db is not None:
        try:
            docs = (
                db.collection(SESSIONS_COL)
                .where("is_analyzed", "==", False)
                .stream()
            )
            for doc in docs:
                data = doc.to_dict()
                created = data.get("created_at")
                if isinstance(created, datetime) and created < cutoff:
                    db.collection(SESSIONS_COL).document(doc.id).update({
                        "is_analyzed": True,
                        "analysis_failed": True,
                        "failure_reason": "Processing timed out (sweeper)",
                    })
                    count += 1
        except Exception as exc:
            logger.warning("Error sweeping stuck sessions from Firestore: %s", exc)
    return count


@router.get("/{session_id}", response_model=SessionResult)
def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Poll this endpoint every ~2 s after finish until is_analyzed=True."""
    doc = db.collection(SESSIONS_COL).document(session_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Session not found")
    data = doc.to_dict()
    if data.get("user_id") != current_user.id:
        raise HTTPException(status_code=404, detail="Session not found")

    session = PracticeSession.from_dict(data)

    # Check if processing has been stuck for >10 minutes
    if not session.is_analyzed and not session.analysis_failed:
        delta = (datetime.now(timezone.utc) - session.created_at).total_seconds()
        if delta > 600:
            logger.warning("Session %s stuck for %.1fs. Marking as failed.", session_id, delta)
            session.is_analyzed = True
            session.analysis_failed = True
            session.failure_reason = "Processing timed out"
            try:
                db.collection(SESSIONS_COL).document(session_id).update({
                    "is_analyzed": True,
                    "analysis_failed": True,
                    "failure_reason": "Processing timed out",
                })
            except Exception:
                pass

    return _to_result(session)


@router.get("", response_model=List[SessionSummary])
def list_sessions(
    mode: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Returns paginated session history for history_screen and home recent card."""
    try:
        query = (
            db.collection(SESSIONS_COL)
            .where("user_id", "==", current_user.id)
        )
        if mode:
            query = query.where("mode", "==", mode)
        all_docs = query.order_by("created_at", direction=fs.Query.DESCENDING).get()
        sessions = [PracticeSession.from_dict(d.to_dict()) for d in all_docs]
    except Exception:
        # Fallback if composite index is not yet deployed in Firestore console
        query = db.collection(SESSIONS_COL).where("user_id", "==", current_user.id)
        if mode:
            query = query.where("mode", "==", mode)
        all_docs = query.get()
        sessions = [PracticeSession.from_dict(d.to_dict()) for d in all_docs]
        sessions.sort(key=lambda s: s.created_at, reverse=True)

    if search:
        search_lower = search.lower()
        sessions = [s for s in sessions if search_lower in s.topic_or_question.lower()]

    # Manual pagination
    start = (page - 1) * limit
    sessions = sessions[start: start + limit]

    return [_to_summary(s) for s in sessions]
