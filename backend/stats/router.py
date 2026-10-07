"""Stats endpoints: summary, trend chart, skill breakdown."""
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import List

from fastapi import APIRouter, Depends, Query
from google.cloud import firestore as fs

from auth.dependencies import get_current_user
from firestore import get_db
from models import PracticeSession, User, SESSIONS_COL
from schemas import SkillBreakdown, StatsSummary, TrendPoint

router = APIRouter(prefix="/stats", tags=["stats"])


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _get_analyzed_sessions(db: fs.Client, user_id: str) -> List[PracticeSession]:
    docs = (
        db.collection(SESSIONS_COL)
        .where("user_id", "==", user_id)
        .where("is_analyzed", "==", True)
        .get()
    )
    sessions = [PracticeSession.from_dict(d.to_dict()) for d in docs]
    return [s for s in sessions if not s.analysis_failed]


def _streak(sessions: List[PracticeSession]) -> int:
    """Count consecutive days with at least one session (from today backwards)."""
    if not sessions:
        return 0
    dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
    today = datetime.now(timezone.utc).date()
    streak = 0
    # A streak is still alive if the last session was yesterday; it only
    # breaks once a full day has passed with no practice.
    expected = today if today in dates else today - timedelta(days=1)
    for d in dates:
        if d == expected:
            streak += 1
            expected -= timedelta(days=1)
        elif d < expected:
            break
    return streak


def _filler_reduction(sessions: List[PracticeSession]) -> float:
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
    db: fs.Client = Depends(get_db),
):
    sessions = _get_analyzed_sessions(db, current_user.id)
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
    db: fs.Client = Depends(get_db),
):
    days = 7 if range == "week" else 30
    since = datetime.now(timezone.utc) - timedelta(days=days)

    docs = (
        db.collection(SESSIONS_COL)
        .where("user_id", "==", current_user.id)
        .where("is_analyzed", "==", True)
        .where("created_at", ">=", since)
        .order_by("created_at")
        .get()
    )
    sessions = [PracticeSession.from_dict(d.to_dict()) for d in docs]
    sessions = [s for s in sessions if not s.analysis_failed]

    grouped: dict = defaultdict(list)
    for s in sessions:
        if range == "week":
            key = s.created_at.strftime("%a")
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
    db: fs.Client = Depends(get_db),
):
    # Fetch last 20 analyzed sessions
    docs = (
        db.collection(SESSIONS_COL)
        .where("user_id", "==", current_user.id)
        .where("is_analyzed", "==", True)
        .order_by("created_at", direction=fs.Query.DESCENDING)
        .limit(20)
        .get()
    )
    sessions = [PracticeSession.from_dict(d.to_dict()) for d in docs]
    sessions = [s for s in sessions if not s.analysis_failed]

    if not sessions:
        return SkillBreakdown(clarity=0, pace=0, filler_words=0, confidence=0, engagement=0)

    n = len(sessions)
    avg_clarity = sum(s.clarity_score or 0 for s in sessions) / n
    avg_conf = sum(s.confidence_score or 0 for s in sessions) / n

    pace_scores = []
    for s in sessions:
        wpm = s.wpm or 0
        if wpm > 0:
            dev = max(0.0, abs(wpm - 140) - 20)
            pace_scores.append(max(0.0, 100.0 - dev * 0.8))
    avg_pace = sum(pace_scores) / max(len(pace_scores), 1)

    filler_scores = []
    for s in sessions:
        wc = len((s.transcript or "").split())
        rate = ((s.filler_word_count or 0) / max(wc, 1)) * 100
        filler_scores.append(max(0.0, 100.0 - rate * 3.0))
    avg_filler = sum(filler_scores) / max(len(filler_scores), 1)

    avg_engagement = avg_conf * 0.6 + avg_clarity * 0.4

    return SkillBreakdown(
        clarity=round(min(avg_clarity, 100.0), 1),
        pace=round(min(avg_pace, 100.0), 1),
        filler_words=round(min(avg_filler, 100.0), 1),
        confidence=round(min(avg_conf, 100.0), 1),
        engagement=round(min(avg_engagement, 100.0), 1),
    )
