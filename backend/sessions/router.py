"""Session CRUD routes: start, finish (upload + async pipeline), get, list."""
import os
import uuid
from typing import List, Optional

import aiofiles
from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session as DbSession

from auth.dependencies import get_current_user
from config import get_settings
from database import get_db
from models import PracticeSession, User
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
os.makedirs(settings.AUDIO_UPLOAD_DIR, exist_ok=True)


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
    )


# ─────────────────────────────────────────────────────────────────────────────
# Background pipeline task
# ─────────────────────────────────────────────────────────────────────────────

def _run_pipeline_bg(
    session_id: str,
    audio_path: str,
    duration: float,
    user_profile: dict,
) -> None:
    """Runs in a background thread (FastAPI BackgroundTasks)."""
    from database import SessionLocal  # local import avoids circular issues

    db = SessionLocal()
    try:
        session = db.query(PracticeSession).filter(PracticeSession.id == session_id).first()
        if not session:
            return

        analysis = analyze_audio(
            audio_path=audio_path,
            duration_seconds=duration,
            user_profile=user_profile,
            groq_api_key=settings.GROQ_API_KEY,
        )

        session.transcript = analysis.transcript
        session.wpm = analysis.wpm
        session.filler_word_count = analysis.filler.total_count
        session.filler_word_breakdown = analysis.filler.breakdown
        session.pause_count = analysis.pauses.count
        session.avg_pause_length = analysis.pauses.avg_length
        session.clarity_score = analysis.clarity_score
        session.confidence_score = analysis.confidence_score
        session.overall_score = analysis.overall_score
        session.duration_seconds = analysis.duration_seconds
        session.ai_feedback = [
            {
                "category": f.category,
                "message": f.message,
                "severity": f.severity,
                "example": f.example,
            }
            for f in analysis.ai_feedback
        ]
        session.is_analyzed = True
        db.commit()
        print(f"[pipeline] Session {session_id} analyzed OK. Score={analysis.overall_score:.1f}")

    except Exception as exc:
        print(f"[pipeline] ERROR for session {session_id}: {exc}")
        # Mark as analyzed so the app doesn't poll forever
        session = db.query(PracticeSession).filter(PracticeSession.id == session_id).first()
        if session:
            session.is_analyzed = True
            db.commit()
    finally:
        db.close()


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/start", response_model=StartSessionResponse)
def start_session(
    req: StartSessionRequest,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    """Creates a session record and returns its ID. Recording happens on the device."""
    session = PracticeSession(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        mode=req.mode,
        topic_or_question=req.topic_or_question,
    )
    db.add(session)
    db.commit()
    return StartSessionResponse(session_id=session.id)


@router.post("/{session_id}/finish", response_model=SessionResult)
async def finish_session(
    session_id: str,
    background_tasks: BackgroundTasks,
    audio_file: UploadFile = File(...),
    duration_seconds: float = Form(0.0),
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    """
    Receives the recorded audio file, saves it to disk, then kicks off the
    AI pipeline in the background.  Returns the session row immediately
    (is_analyzed=False); the Flutter app polls GET /{id} until is_analyzed=True.
    """
    session = db.query(PracticeSession).filter(
        PracticeSession.id == session_id,
        PracticeSession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Save audio file to disk
    raw_name = audio_file.filename or "recording.m4a"
    ext = os.path.splitext(raw_name)[1] or ".m4a"
    filename = f"{session_id}{ext}"
    audio_path = os.path.join(settings.AUDIO_UPLOAD_DIR, filename)

    async with aiofiles.open(audio_path, "wb") as f:
        content = await audio_file.read()
        await f.write(content)

    session.audio_url = audio_path
    session.duration_seconds = duration_seconds
    db.commit()

    # Kick off AI pipeline in background
    user_profile = {
        "feedback_style": current_user.feedback_style,
        "experience_level": current_user.experience_level,
    }
    background_tasks.add_task(
        _run_pipeline_bg, session_id, audio_path, duration_seconds, user_profile
    )

    db.refresh(session)
    return _to_result(session)


@router.get("/{session_id}", response_model=SessionResult)
def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    """Poll this endpoint every ~2 s after finish until is_analyzed=True."""
    session = db.query(PracticeSession).filter(
        PracticeSession.id == session_id,
        PracticeSession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return _to_result(session)


@router.get("", response_model=List[SessionSummary])
def list_sessions(
    mode: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    """Returns paginated session history for history_screen and home recent card."""
    q = db.query(PracticeSession).filter(PracticeSession.user_id == current_user.id)
    if mode:
        q = q.filter(PracticeSession.mode == mode)
    if search:
        q = q.filter(PracticeSession.topic_or_question.ilike(f"%{search}%"))
    sessions = (
        q.order_by(PracticeSession.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
        .all()
    )
    return [_to_summary(s) for s in sessions]
