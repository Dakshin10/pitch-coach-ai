"""
Pydantic request/response schemas — the API contract.
All field names here must match what the Flutter app expects.
"""
from __future__ import annotations
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, EmailStr, Field, field_validator


# ─────────────────────────────────────────────────────────────────────────────
# Auth
# ─────────────────────────────────────────────────────────────────────────────

class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128, description="Password must be between 8 and 128 characters")
    full_name: str = Field(..., min_length=1, max_length=100, description="Full name must not exceed 100 characters")

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v


class RefreshRequest(BaseModel):
    refresh_token: str


class FirebaseLoginRequest(BaseModel):
    id_token: str


class UpgradeGuestRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128, description="Password must be between 8 and 128 characters")
    full_name: str = Field(..., min_length=1, max_length=100, description="Full name must not exceed 100 characters")

    @field_validator("email", mode="before")
    @classmethod
    def normalize_email(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().lower()
        return v


class UserResponse(BaseModel):
    id: str
    email: Optional[str] = None
    full_name: str
    role_occupation: str
    primary_objective: str
    target_industry: str
    experience_level: str
    feedback_style: str
    is_guest: bool
    dark_mode: bool

    model_config = {"from_attributes": True}


class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


# ─────────────────────────────────────────────────────────────────────────────
# Profile
# ─────────────────────────────────────────────────────────────────────────────

class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    role_occupation: Optional[str] = None
    primary_objective: Optional[str] = None
    target_industry: Optional[str] = None
    experience_level: Optional[str] = None
    feedback_style: Optional[str] = None
    dark_mode: Optional[bool] = None


# ─────────────────────────────────────────────────────────────────────────────
# Sessions
# ─────────────────────────────────────────────────────────────────────────────

class StartSessionRequest(BaseModel):
    session_id: Optional[str] = None
    mode: str = "interview"
    topic_or_question: str = "Tell me about yourself."
    local_date: Optional[str] = None
    tz_offset_minutes: Optional[int] = None

    @field_validator("session_id")
    @classmethod
    def validate_session_id(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            import uuid
            try:
                uuid.UUID(v)
            except ValueError:
                raise ValueError("session_id must be a valid UUID")
        return v

    @field_validator("local_date")
    @classmethod
    def validate_local_date(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v = v.strip()
            import re
            if not re.match(r"^\d{4}-\d{2}-\d{2}$", v):
                raise ValueError("local_date must be in YYYY-MM-DD format")
            from datetime import datetime
            try:
                datetime.strptime(v, "%Y-%m-%d")
            except ValueError:
                raise ValueError("local_date must be a valid calendar date in YYYY-MM-DD format")
        return v

    @field_validator("tz_offset_minutes")
    @classmethod
    def validate_tz_offset(cls, v: Optional[int]) -> Optional[int]:
        if v is not None:
            if not (-720 <= v <= 840):
                raise ValueError("tz_offset_minutes must be between -720 and 840")
        return v


class StartSessionResponse(BaseModel):
    session_id: str


class FeedbackItem(BaseModel):
    category: str                   # filler_words / pacing / clarity / structure / confidence
    message: str
    severity: str                   # tip / warning / positive
    example: Optional[str] = None


class SessionResult(BaseModel):
    id: str
    mode: str
    topic_or_question: str
    duration_seconds: float
    transcript: Optional[str] = None
    wpm: float
    filler_word_count: int
    filler_word_breakdown: Dict[str, int]
    pause_count: int
    avg_pause_length: float
    clarity_score: float
    confidence_score: float
    overall_score: float
    ai_feedback: List[FeedbackItem]
    created_at: datetime
    local_date: Optional[str] = None
    tz_offset_minutes: Optional[int] = None
    is_analyzed: bool
    analysis_failed: bool = False
    failure_reason: Optional[str] = None
    audio_url: Optional[str] = None

    model_config = {"from_attributes": True}


class SessionSummary(BaseModel):
    id: str
    mode: str
    topic_or_question: str
    duration_seconds: float
    overall_score: float
    confidence_score: float
    created_at: datetime
    local_date: Optional[str] = None
    tz_offset_minutes: Optional[int] = None
    is_analyzed: bool
    analysis_failed: bool = False
    failure_reason: Optional[str] = None

    model_config = {"from_attributes": True}


# ─────────────────────────────────────────────────────────────────────────────
# Stats
# ─────────────────────────────────────────────────────────────────────────────

class StatsSummary(BaseModel):
    total_sessions: int
    avg_confidence: float
    streak_days: int
    filler_reduction_pct: float     # positive = improvement, negative = got worse
    avg_score: Optional[float] = None
    avg_wpm: Optional[float] = None
    avg_clarity: Optional[float] = None
    total_duration: Optional[float] = None


class TrendPoint(BaseModel):
    date: str                       # "Mon" / "W1" depending on range
    confidence: float


class StreakResponse(BaseModel):
    streak: int
    last_day: Optional[str] = None


class SkillBreakdown(BaseModel):
    clarity: float
    pace: float
    filler_words: float
    confidence: float
    engagement: float


# ─────────────────────────────────────────────────────────────────────────────
# Achievements
# ─────────────────────────────────────────────────────────────────────────────

class AchievementResponse(BaseModel):
    key: str
    title: str
    icon: str
    is_unlocked: bool
    unlocked_at: Optional[datetime] = None
    description: str
