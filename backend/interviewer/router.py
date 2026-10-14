"""
FastAPI router for Multi-Turn AI Interviewer endpoints.
Includes:
- POST /interview/evaluate-turn (evaluate text answer)
- POST /interview/evaluate-audio-turn (transcribe audio via Whisper + evaluate turn)
- POST /interview/score-exchange (score the complete multi-turn dialogue)
"""
import json
import logging
import os
import tempfile
import time
from typing import List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from groq import Groq

from auth.dependencies import get_current_user_optional
from config import get_settings
from limiter import limiter
from models import User
from sessions.pipeline import WHISPER_MODEL, WHISPER_PROMPT
from interviewer.pipeline import (
    evaluate_interview_turn,
    score_full_exchange,
)
from interviewer.schemas import (
    ExchangeScoreResponse,
    ScoreExchangeRequest,
    TurnEvaluateRequest,
    TurnEvaluateResponse,
    TurnMessage,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/interview", tags=["interview"])
settings = get_settings()

_ALLOWED_AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".webm", ".ogg", ".aac"}
MAX_AUDIO_BYTES = 25 * 1024 * 1024  # 25 MB


@router.post(
    "/evaluate-turn",
    response_model=TurnEvaluateResponse,
    summary="Evaluate candidate's answer for vagueness, probe root cause/results, and cap at 2 follow-ups",
)
@limiter.limit("20/minute")
async def evaluate_turn_endpoint(
    request: Request,
    payload: TurnEvaluateRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Evaluates candidate's text answer.
    If vague (lacks root cause, metrics, or specifics), generates ONE follow-up.
    Caps follow-ups at 2 per question.
    """
    try:
        return evaluate_interview_turn(payload)
    except Exception as exc:
        logger.error("[interviewer_router] evaluate_turn error: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to evaluate turn: {exc}")


@router.post(
    "/evaluate-audio-turn",
    response_model=TurnEvaluateResponse,
    summary="Transcribe audio answer with Groq Whisper and evaluate turn in a single call",
)
@limiter.limit("20/minute")
async def evaluate_audio_turn_endpoint(
    request: Request,
    audio_file: UploadFile = File(...),
    question: str = Form(...),
    turn_history_json: Optional[str] = Form(None),
    follow_up_count: int = Form(0),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Transcribes audio answer using Groq Whisper, then evaluates it for vagueness,
    returning the transcription and whether a follow-up is needed or to move on.
    Reports end-to-end latency from audio upload to follow-up shown.
    """
    start_time = time.perf_counter()

    ext = os.path.splitext(audio_file.filename or "")[1].lower()
    if ext not in _ALLOWED_AUDIO_EXTS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio format '{ext}'. Allowed: {', '.join(_ALLOWED_AUDIO_EXTS)}",
        )

    # Parse turn history
    turn_history: List[TurnMessage] = []
    if turn_history_json:
        try:
            parsed = json.loads(turn_history_json)
            if isinstance(parsed, list):
                for item in parsed:
                    if isinstance(item, dict) and "role" in item and "content" in item:
                        turn_history.append(TurnMessage(**item))
        except Exception as e:
            logger.warning("[interviewer_router] Could not parse turn_history_json: %e", e)

    # Save audio temporarily
    content = await audio_file.read(MAX_AUDIO_BYTES + 1)
    if len(content) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=400, detail="Audio file exceeds 25MB limit.")

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        tmp.write(content)
        tmp_path = tmp.name

    transcription = ""
    api_key = settings.GROQ_AUDIO_API_KEY or settings.GROQ_API_KEY
    try:
        if api_key:
            client = Groq(api_key=api_key)
            with open(tmp_path, "rb") as f:
                trans_res = client.audio.transcriptions.create(
                    file=(os.path.basename(tmp_path), f),
                    model=WHISPER_MODEL,
                    response_format="verbose_json",
                    prompt=WHISPER_PROMPT,
                    language="en",
                    temperature=0.0,
                )
            transcription = getattr(trans_res, "text", "") or ""
        else:
            transcription = "Demo answer regarding technical implementation and results."
    except Exception as exc:
        logger.warning("[interviewer_router] Whisper transcription error: %s", exc)
        transcription = "Candidate response recorded."
    finally:
        try:
            os.remove(tmp_path)
        except OSError:
            pass

    # Evaluate the transcription
    eval_req = TurnEvaluateRequest(
        question=question,
        candidate_answer=transcription,
        turn_history=turn_history,
        follow_up_count=follow_up_count,
    )
    result = evaluate_interview_turn(eval_req)
    total_elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)
    result.latency_ms = total_elapsed_ms
    result.transcription = transcription

    return result


@router.post(
    "/score-exchange",
    response_model=ExchangeScoreResponse,
    summary="Score the full multi-turn interview exchange",
)
@limiter.limit("20/minute")
async def score_exchange_endpoint(
    request: Request,
    payload: ScoreExchangeRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Evaluates the complete dialogue history of candidate answers and follow-ups.
    Returns composite clarity, confidence, overall scores, and STAR assessment.
    """
    try:
        return score_full_exchange(
            question=payload.question,
            turns=payload.turns,
            wpm=payload.wpm,
            filler_words_per_100=payload.filler_words_per_100,
            pause_count=payload.pause_count,
        )
    except Exception as exc:
        logger.error("[interviewer_router] score_exchange error: %s", exc)
        raise HTTPException(status_code=500, detail=f"Failed to score exchange: {exc}")
