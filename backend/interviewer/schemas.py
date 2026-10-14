"""
Pydantic schemas for Multi-Turn AI Interviewer feature.
"""
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class TurnMessage(BaseModel):
    role: str = Field(..., description="'interviewer' or 'candidate'")
    content: str = Field(..., description="Message text content")


class TurnEvaluateRequest(BaseModel):
    question: str = Field(..., description="Original interview question")
    candidate_answer: str = Field(..., description="Latest candidate answer")
    turn_history: List[TurnMessage] = Field(
        default_factory=list,
        description="Previous dialogue turns for context"
    )
    follow_up_count: int = Field(
        default=0,
        ge=0,
        description="Number of follow-up questions already asked so far"
    )


class TurnEvaluateResponse(BaseModel):
    follow_up: Optional[str] = Field(
        None,
        description="Follow-up question if answer is vague, or None if moving on"
    )
    move_on: bool = Field(
        ...,
        description="True if candidate can move to next question, False if follow-up asked"
    )
    reason: str = Field(
        ...,
        description="Explanation of why follow-up was needed or why answer is satisfactory"
    )
    is_vague: bool = Field(
        default=False,
        description="True if missing root cause, measurable result, or concrete specifics"
    )
    latency_ms: Optional[float] = Field(
        None,
        description="End-to-end processing latency in milliseconds"
    )
    transcription: Optional[str] = Field(
        None,
        description="Whisper transcription if audio was submitted"
    )


class ScoreExchangeRequest(BaseModel):
    question: str = Field(..., description="Interview question")
    turns: List[TurnMessage] = Field(
        ...,
        description="Full multi-turn exchange including all interviewer and candidate turns"
    )
    wpm: Optional[float] = Field(None, description="Average speaking rate across exchange")
    filler_words_per_100: Optional[float] = Field(None, description="Filler rate across exchange")
    pause_count: Optional[int] = Field(None, description="Total pauses >1.5s across exchange")


class ExchangeScoreResponse(BaseModel):
    clarity_score: float = Field(..., ge=0, le=100)
    confidence_score: float = Field(..., ge=0, le=100)
    overall_score: float = Field(..., ge=0, le=100)
    feedback_summary: str = Field(..., description="Summary of multi-turn performance")
    strengths: List[str] = Field(default_factory=list)
    improvements: List[str] = Field(default_factory=list)
    star_assessment: Optional[Dict[str, str]] = Field(
        None,
        description="Assessment of Situation, Task, Action, and Result across the full answer"
    )
    latency_ms: Optional[float] = Field(None, description="Scoring latency in milliseconds")
