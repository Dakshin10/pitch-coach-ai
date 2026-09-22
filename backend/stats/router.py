"""Stats endpoints: summary, trend chart, skill breakdown."""
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session as DbSession

from auth.dependencies import get_current_user
from database import get_db
from models import PracticeSession, User
from schemas import SkillBreakdown, StatsSummary, TrendPoint

router = APIRouter(prefix="/stats", tags=["stats"])


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _streak(sessions: list) -> int:
    """Count consecutive days with at least one session (from today backwards)."""
    if not sessions:
        return 0
    dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
    today = datetime.now(timezone.utc).date()
    streak = 0
    expected = today
    for d in dates:
        if d == expected:
            streak += 1
            expected -= timedelta(days=1)
        elif d < expected:
            break
    return streak


def _filler_reduction(sessions: list) -> float:
    """Percentage improvement in filler count between first half and second half of sessions."""
    if len(sessions) < 2:
        return 0.0
    ordered = sorted(sessions, key=lambda s: s.created_at)
    half = max(1, len(ordered) // 2)
    old_avg = sum((s.filler_word_count or 0) for s in ordered[:half]) / half
    new_avg = sum((s.filler_word_count or 0) for s in ordered[half:]) / max(len(ordered) - half, 1)
    if old_avg == 0:
        return 0.0
    return round((old_avg - new_avg) / old_avg * 100.0, 1)


# ─────────────────────────────────────────────────────────────────────────────
# Routes
# ─────────────────────────────────────────────────────────────────────────────

@router.get("/summary", response_model=StatsSummary)
def get_summary(
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    sessions = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == current_user.id, PracticeSession.is_analyzed == True)
        .all()
    )
    n = len(sessions)
    avg_conf = sum(s.confidence_score or 0 for s in sessions) / max(n, 1)
    return StatsSummary(
        total_sessions=n,
        avg_confidence=round(avg_conf, 1),
        streak_days=_streak(sessions),
        filler_reduction_pct=_filler_reduction(sessions),
    )


@router.get("/trend", response_model=List[TrendPoint])
def get_trend(
    range: str = Query("week", enum=["week", "month"]),
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    days = 7 if range == "week" else 30
    since = datetime.now(timezone.utc) - timedelta(days=days)

    sessions = (
        db.query(PracticeSession)
        .filter(
            PracticeSession.user_id == current_user.id,
            PracticeSession.is_analyzed == True,
            PracticeSession.created_at >= since,
        )
        .order_by(PracticeSession.created_at.asc())
        .all()
    )

    grouped: dict = defaultdict(list)
    for s in sessions:
        if range == "week":
            key = s.created_at.strftime("%a")     # Mon, Tue ...
        else:
            wk = (s.created_at.day - 1) // 7 + 1
            key = f"W{wk}"
        grouped[key].append(s.confidence_score or 0)

    return [
        TrendPoint(date=k, confidence=round(sum(v) / len(v), 1))
        for k, v in grouped.items()
    ]


@router.get("/skills", response_model=SkillBreakdown)
def get_skills(
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    sessions = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == current_user.id, PracticeSession.is_analyzed == True)
        .order_by(PracticeSession.created_at.desc())
        .limit(20)
        .all()
    )
    if not sessions:
        return SkillBreakdown(clarity=0, pace=0, filler_words=0, confidence=0, engagement=0)

    n = len(sessions)
    avg_clarity = sum(s.clarity_score or 0 for s in sessions) / n
    avg_conf = sum(s.confidence_score or 0 for s in sessions) / n

    # Pace score: proximity to 140 WPM ± 20
    pace_scores = []
    for s in sessions:
        wpm = s.wpm or 0
        if wpm > 0:
            dev = max(0.0, abs(wpm - 140) - 20)
            pace_scores.append(max(0.0, 100.0 - dev * 0.8))
    avg_pace = sum(pace_scores) / max(len(pace_scores), 1)

    # Filler words score: inverse of filler rate
    filler_scores = []
    for s in sessions:
        wc = len((s.transcript or "").split())
        rate = ((s.filler_word_count or 0) / max(wc, 1)) * 100
        filler_scores.append(max(0.0, 100.0 - rate * 3.0))
    avg_filler = sum(filler_scores) / max(len(filler_scores), 1)

    # Engagement: weighted blend of confidence + clarity
    avg_engagement = avg_conf * 0.6 + avg_clarity * 0.4

    return SkillBreakdown(
        clarity=round(min(avg_clarity, 100.0), 1),
        pace=round(min(avg_pace, 100.0), 1),
        filler_words=round(min(avg_filler, 100.0), 1),
        confidence=round(min(avg_conf, 100.0), 1),
        engagement=round(min(avg_engagement, 100.0), 1),
    )
