"""Metrics changes sync endpoint.

Provides keyset pagination over session_metrics, session_fillers, and user_achievements
for offline-first pull sync into local SQLite.
"""
from datetime import datetime, timezone
import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Query
from google.cloud import firestore as fs
from pydantic import BaseModel

from auth.dependencies import get_current_user
from d1.d1_client import get_d1_client
from firestore import get_db
from models import User, SESSIONS_COL, ACHIEVEMENTS_COL

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/metrics", tags=["metrics"])


class MetricsChangesResponse(BaseModel):
    sessions: List[Dict[str, Any]]
    fillers: List[Dict[str, Any]]
    achievements: List[Dict[str, Any]]
    next_cursor_updated_at: Optional[str] = None
    next_cursor_id: Optional[str] = None
    has_more: bool = False


@router.get("/changes", response_model=MetricsChangesResponse)
def get_metrics_changes(
    cursor_updated_at: Optional[str] = Query(None, description="ISO-8601 UTC timestamp of last sync cursor"),
    cursor_id: Optional[str] = Query(None, description="Session ID tie-breaker of last sync cursor"),
    limit: int = Query(200, ge=1, le=500),
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Returns incremental changes ordered by (updated_at, id).

    Includes tombstones (deleted_at IS NOT NULL) and achievements changes.
    """
    d1 = get_d1_client()

    if d1.is_configured:
        try:
            # 1. Query session_metrics changes
            if cursor_updated_at and cursor_id:
                sessions_sql = """
                SELECT * FROM session_metrics
                WHERE user_id = ?
                  AND (updated_at > ? OR (updated_at = ? AND id > ?))
                ORDER BY updated_at ASC, id ASC
                LIMIT ?;
                """
                params = [current_user.id, cursor_updated_at, cursor_updated_at, cursor_id, limit + 1]
            elif cursor_updated_at:
                sessions_sql = """
                SELECT * FROM session_metrics
                WHERE user_id = ?
                  AND updated_at >= ?
                ORDER BY updated_at ASC, id ASC
                LIMIT ?;
                """
                params = [current_user.id, cursor_updated_at, limit + 1]
            else:
                # Full history pull (null cursor)
                sessions_sql = """
                SELECT * FROM session_metrics
                WHERE user_id = ?
                ORDER BY updated_at ASC, id ASC
                LIMIT ?;
                """
                params = [current_user.id, limit + 1]

            session_rows = d1.query(sessions_sql, params)
            has_more = len(session_rows) > limit
            if has_more:
                page_sessions = session_rows[:limit]
            else:
                page_sessions = session_rows

            next_cursor_updated_at = None
            next_cursor_id = None
            if page_sessions:
                last_row = page_sessions[-1]
                next_cursor_updated_at = last_row.get("updated_at")
                next_cursor_id = last_row.get("id")

            # 2. Query session_fillers for these sessions
            fillers_rows = []
            if page_sessions:
                session_ids = [s["id"] for s in page_sessions if s.get("id")]
                if session_ids:
                    placeholders = ",".join("?" for _ in session_ids)
                    fillers_sql = f"SELECT session_id, filler_word, count FROM session_fillers WHERE session_id IN ({placeholders})"
                    fillers_rows = d1.query(fillers_sql, session_ids)

            # 3. Query user_achievements
            if cursor_updated_at:
                ach_sql = """
                SELECT * FROM user_achievements
                WHERE user_id = ? AND updated_at >= ?
                ORDER BY updated_at ASC;
                """
                ach_rows = d1.query(ach_sql, [current_user.id, cursor_updated_at])
            else:
                ach_sql = """
                SELECT * FROM user_achievements
                WHERE user_id = ?
                ORDER BY updated_at ASC;
                """
                ach_rows = d1.query(ach_sql, [current_user.id])

            return MetricsChangesResponse(
                sessions=page_sessions,
                fillers=fillers_rows,
                achievements=ach_rows,
                next_cursor_updated_at=next_cursor_updated_at,
                next_cursor_id=next_cursor_id,
                has_more=has_more,
            )

        except Exception as exc:
            logger.warning("[metrics] D1 query error in /changes (%s), falling back to Firestore.", exc)

    # Fallback to Firestore
    try:
        # Avoid composite index requirement by filtering user_id in Firestore and sorting in Python
        query = db.collection(SESSIONS_COL).where("user_id", "==", current_user.id).limit(limit)
        docs = query.get()
        sessions = []
        fillers = []
        for d in docs:
            data = d.to_dict() or {}
            sid = d.id
            now_iso = (data.get("created_at") or datetime.now(timezone.utc)).isoformat()
            sessions.append({
                "id": sid,
                "user_id": current_user.id,
                "mode": data.get("mode", "interview"),
                "topic_or_question": data.get("topic_or_question", ""),
                "duration_seconds": float(data.get("duration_seconds", 0.0) or 0.0),
                "wpm": float(data.get("wpm", 0.0) or 0.0),
                "filler_word_count": int(data.get("filler_word_count", 0) or 0),
                "pause_count": int(data.get("pause_count", 0) or 0),
                "avg_pause_length": float(data.get("avg_pause_length", 0.0) or 0.0),
                "clarity_score": float(data.get("clarity_score", 0.0) or 0.0),
                "confidence_score": float(data.get("confidence_score", 0.0) or 0.0),
                "overall_score": float(data.get("overall_score", 0.0) or 0.0),
                "status": "analyzed" if data.get("is_analyzed") else "pending",
                "created_at": now_iso,
                "local_date": data.get("local_date") or now_iso[:10],
                "tz_offset_minutes": data.get("tz_offset_minutes", 0),
                "updated_at": now_iso,
                "deleted_at": None,
            })
            for w, c in (data.get("filler_word_breakdown") or {}).items():
                fillers.append({"session_id": sid, "filler_word": w, "count": c})

        last_updated = sessions[-1]["updated_at"] if sessions else None
        last_id = sessions[-1]["id"] if sessions else None

        return MetricsChangesResponse(
            sessions=sessions,
            fillers=fillers,
            achievements=[],
            next_cursor_updated_at=last_updated,
            next_cursor_id=last_id,
            has_more=False,
        )
    except Exception as exc:
        logger.error("[metrics] Firestore fallback error in /changes: %s", exc)
        return MetricsChangesResponse(sessions=[], fillers=[], achievements=[])
