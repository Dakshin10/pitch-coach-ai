"""Achievements: evaluate criteria, persist unlocks, return full list."""
import uuid
from datetime import datetime, timedelta, timezone
from typing import Callable, List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DbSession

from auth.dependencies import get_current_user
from database import get_db
from models import Achievement, PracticeSession, User
from schemas import AchievementResponse

router = APIRouter(prefix="/achievements", tags=["achievements"])


# ─────────────────────────────────────────────────────────────────────────────
# Achievement definitions
# ─────────────────────────────────────────────────────────────────────────────

def _has_n_day_streak(sessions: list, n: int) -> bool:
    dates = sorted(set(s.created_at.date() for s in sessions), reverse=True)
    if not dates:
        return False
    streak, prev = 1, dates[0]
    for d in dates[1:]:
        if (prev - d).days == 1:
            streak += 1
            if streak >= n:
                return True
            prev = d
        else:
            streak, prev = 1, d
    return streak >= n


ACHIEVEMENT_DEFS: List[dict] = [
    {
        "key": "first_session",
        "title": "First Step",
        "icon": "🎤",
        "check": lambda s, _u: len(s) >= 1,
        "desc": lambda s, _u: "Complete your first practice session.",
    },
    {
        "key": "7_day_streak",
        "title": "7-Day Streak",
        "icon": "🔥",
        "check": lambda s, _u: _has_n_day_streak(s, 7),
        "desc": lambda s, _u: "Practice 7 days in a row.",
    },
    {
        "key": "50_sessions",
        "title": "50 Sessions",
        "icon": "🎯",
        "check": lambda s, _u: len(s) >= 50,
        "desc": lambda s, _u: f"Complete 50 practice sessions. {len(s)}/50 so far.",
    },
    {
        "key": "clarity_master",
        "title": "Clarity Master",
        "icon": "💎",
        "check": lambda s, _u: any((x.clarity_score or 0) >= 85 for x in s),
        "desc": lambda s, _u: "Achieve a clarity score ≥ 85% in any session.",
    },
    {
        "key": "early_bird",
        "title": "Early Bird",
        "icon": "🌅",
        "check": lambda s, _u: any(x.created_at.hour < 8 for x in s),
        "desc": lambda s, _u: "Complete a session before 8:00 AM.",
    },
]


@router.get("", response_model=List[AchievementResponse])
def get_achievements(
    current_user: User = Depends(get_current_user),
    db: DbSession = Depends(get_db),
):
    sessions = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == current_user.id, PracticeSession.is_analyzed == True)
        .all()
    )
    existing = {
        a.key: a
        for a in db.query(Achievement).filter(Achievement.user_id == current_user.id).all()
    }

    result = []
    for defn in ACHIEVEMENT_DEFS:
        key = defn["key"]
        is_unlocked: bool = defn["check"](sessions, current_user)

        # Persist newly unlocked achievements
        if is_unlocked and key not in existing:
            ach = Achievement(
                id=str(uuid.uuid4()),
                user_id=current_user.id,
                key=key,
                unlocked_at=datetime.now(timezone.utc),
                criteria_met={"session_count": len(sessions)},
            )
            db.add(ach)
            db.commit()
            existing[key] = ach

        unlocked_at = existing[key].unlocked_at if (key in existing and is_unlocked) else None

        result.append(AchievementResponse(
            key=key,
            title=defn["title"],
            icon=defn["icon"],
            is_unlocked=is_unlocked,
            unlocked_at=unlocked_at,
            description=defn["desc"](sessions, current_user),
        ))

    return result
