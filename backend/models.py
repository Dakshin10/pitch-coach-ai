"""
Plain Python dataclasses that mirror Firestore document shapes.
No SQLAlchemy — documents are dicts in Firestore; these classes are used
for type-safety inside the Python backend only.
"""
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


def _gen_uuid() -> str:
    return str(uuid.uuid4())


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


# ─────────────────────────────────────────────────────────────────────────────
# Firestore collection names
# ─────────────────────────────────────────────────────────────────────────────

USERS_COL = "users"
SESSIONS_COL = "sessions"
ACHIEVEMENTS_COL = "achievements"


# ─────────────────────────────────────────────────────────────────────────────
# Data shapes (used as typed dicts when reading/writing Firestore docs)
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class User:
    id: str = field(default_factory=_gen_uuid)
    email: Optional[str] = None
    password_hash: Optional[str] = None
    full_name: str = "Guest User"
    role_occupation: str = ""
    primary_objective: str = "Technical Interviews & Pitch Presentations"
    target_industry: str = "Software & Technology"
    experience_level: str = "Intermediate"
    feedback_style: str = "Encouraging & Constructive"
    is_guest: bool = False
    dark_mode: bool = False
    created_at: datetime = field(default_factory=_now_utc)
    expires_at: Optional[datetime] = None

    # ── Firestore helpers ──────────────────────────────────────────────────

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "email": self.email,
            "password_hash": self.password_hash,
            "full_name": self.full_name,
            "role_occupation": self.role_occupation,
            "primary_objective": self.primary_objective,
            "target_industry": self.target_industry,
            "experience_level": self.experience_level,
            "feedback_style": self.feedback_style,
            "is_guest": self.is_guest,
            "dark_mode": self.dark_mode,
            "created_at": self.created_at,
            "expires_at": self.expires_at,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "User":
        return User(
            id=d.get("id", ""),
            email=d.get("email"),
            password_hash=d.get("password_hash"),
            full_name=d.get("full_name", "Guest User"),
            role_occupation=d.get("role_occupation", ""),
            primary_objective=d.get("primary_objective", ""),
            target_industry=d.get("target_industry", ""),
            experience_level=d.get("experience_level", "Intermediate"),
            feedback_style=d.get("feedback_style", "Encouraging & Constructive"),
            is_guest=d.get("is_guest", False),
            dark_mode=d.get("dark_mode", False),
            created_at=d.get("created_at") or _now_utc(),
            expires_at=d.get("expires_at"),
        )


@dataclass
class PracticeSession:
    id: str = field(default_factory=_gen_uuid)
    user_id: str = ""
    mode: str = "interview"
    topic_or_question: str = "Tell me about yourself."
    audio_url: Optional[str] = None
    duration_seconds: float = 0.0
    transcript: Optional[str] = None

    wpm: float = 0.0
    filler_word_count: int = 0
    filler_word_breakdown: Dict[str, int] = field(default_factory=dict)
    pause_count: int = 0
    avg_pause_length: float = 0.0

    clarity_score: float = 0.0
    confidence_score: float = 0.0
    overall_score: float = 0.0

    ai_feedback: List[Dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=_now_utc)
    is_analyzed: bool = False
    analysis_failed: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "mode": self.mode,
            "topic_or_question": self.topic_or_question,
            "audio_url": self.audio_url,
            "duration_seconds": self.duration_seconds,
            "transcript": self.transcript,
            "wpm": self.wpm,
            "filler_word_count": self.filler_word_count,
            "filler_word_breakdown": self.filler_word_breakdown,
            "pause_count": self.pause_count,
            "avg_pause_length": self.avg_pause_length,
            "clarity_score": self.clarity_score,
            "confidence_score": self.confidence_score,
            "overall_score": self.overall_score,
            "ai_feedback": self.ai_feedback,
            "created_at": self.created_at,
            "is_analyzed": self.is_analyzed,
            "analysis_failed": self.analysis_failed,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "PracticeSession":
        return PracticeSession(
            id=d.get("id", ""),
            user_id=d.get("user_id", ""),
            mode=d.get("mode", "interview"),
            topic_or_question=d.get("topic_or_question", ""),
            audio_url=d.get("audio_url"),
            duration_seconds=d.get("duration_seconds", 0.0),
            transcript=d.get("transcript"),
            wpm=d.get("wpm", 0.0),
            filler_word_count=d.get("filler_word_count", 0),
            filler_word_breakdown=d.get("filler_word_breakdown", {}),
            pause_count=d.get("pause_count", 0),
            avg_pause_length=d.get("avg_pause_length", 0.0),
            clarity_score=d.get("clarity_score", 0.0),
            confidence_score=d.get("confidence_score", 0.0),
            overall_score=d.get("overall_score", 0.0),
            ai_feedback=d.get("ai_feedback", []),
            created_at=d.get("created_at") or _now_utc(),
            is_analyzed=d.get("is_analyzed", False),
            analysis_failed=d.get("analysis_failed", False),
        )


@dataclass
class Achievement:
    id: str = field(default_factory=_gen_uuid)
    user_id: str = ""
    key: str = ""
    unlocked_at: Optional[datetime] = None
    criteria_met: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "user_id": self.user_id,
            "key": self.key,
            "unlocked_at": self.unlocked_at,
            "criteria_met": self.criteria_met,
        }

    @staticmethod
    def from_dict(d: Dict[str, Any]) -> "Achievement":
        return Achievement(
            id=d.get("id", ""),
            user_id=d.get("user_id", ""),
            key=d.get("key", ""),
            unlocked_at=d.get("unlocked_at"),
            criteria_met=d.get("criteria_met", {}),
        )
