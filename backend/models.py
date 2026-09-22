"""
SQLAlchemy ORM models for Pitch Coach.
Table names follow the data model in the implementation plan.
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey,
    Integer, JSON, String, Text,
)
from sqlalchemy.orm import relationship

from database import Base


def _gen_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=_gen_uuid)
    email = Column(String, unique=True, nullable=True, index=True)
    password_hash = Column(String, nullable=True)
    full_name = Column(String, default="Guest User")
    role_occupation = Column(String, default="")
    primary_objective = Column(String, default="Technical Interviews & Pitch Presentations")
    target_industry = Column(String, default="Software & Technology")
    experience_level = Column(String, default="Intermediate")    # beginner/intermediate/advanced
    feedback_style = Column(String, default="Encouraging & Constructive")
    is_guest = Column(Boolean, default=False)
    dark_mode = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=True)  # set for guest accounts

    sessions = relationship("PracticeSession", back_populates="user", cascade="all, delete-orphan")
    achievements = relationship("Achievement", back_populates="user", cascade="all, delete-orphan")


class PracticeSession(Base):
    """Renamed to PracticeSession to avoid conflict with SQLAlchemy's Session object."""
    __tablename__ = "sessions"

    id = Column(String, primary_key=True, default=_gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    mode = Column(String, default="interview")          # interview / presentation / free_talk
    topic_or_question = Column(String, default="Tell me about yourself.")
    audio_url = Column(String, nullable=True)
    duration_seconds = Column(Float, default=0.0)
    transcript = Column(Text, nullable=True)

    # Deterministic metrics (computed by pipeline.py)
    wpm = Column(Float, default=0.0)
    filler_word_count = Column(Integer, default=0)
    filler_word_breakdown = Column(JSON, default=dict)   # {"um": 4, "like": 2, ...}
    pause_count = Column(Integer, default=0)
    avg_pause_length = Column(Float, default=0.0)

    # Composite scores (computed by pipeline.py)
    clarity_score = Column(Float, default=0.0)          # 0-100
    confidence_score = Column(Float, default=0.0)       # 0-100
    overall_score = Column(Float, default=0.0)          # 0-100

    # LLM qualitative feedback
    ai_feedback = Column(JSON, default=list)            # [{category, message, severity, example}]

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    is_analyzed = Column(Boolean, default=False)        # True once pipeline finishes

    user = relationship("User", back_populates="sessions")


class Achievement(Base):
    __tablename__ = "achievements"

    id = Column(String, primary_key=True, default=_gen_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    key = Column(String, nullable=False)                # e.g. "7_day_streak"
    unlocked_at = Column(DateTime, nullable=True)
    criteria_met = Column(JSON, default=dict)

    user = relationship("User", back_populates="achievements")
