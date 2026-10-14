"""Tests for Feature 11: Weekly Challenges and Privacy-Preserving Leaderboard."""
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from achievements.challenges import (
    CHALLENGE_DEFINITIONS,
    evaluate_user_challenges,
    get_current_week_id,
    get_current_week_start,
)
from achievements.leaderboard import generate_pseudonym, get_weekly_leaderboard
from auth.dependencies import get_current_user
from firestore import get_db
from main import app
from models import User


@pytest.fixture
def mock_user():
    return User(
        id="test-gamification-user-42",
        email="secret_speaker@domain.com",
        full_name="Alex Mercer",
        settings={
            "leaderboard_opt_in": False,
            "gamification_points": 0,
            "claimed_challenges": {},
        },
    )


@pytest.fixture
def client(mock_user):
    mock_db = MagicMock()
    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_db] = lambda: mock_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


# ─────────────────────────────────────────────────────────────────────────────
# 1. Challenge Evaluation Unit Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_pseudonym_generation_privacy():
    p1 = generate_pseudonym("user-abc")
    p2 = generate_pseudonym("user-abc")
    p3 = generate_pseudonym("user-xyz")

    assert p1 == p2, "Pseudonym must be deterministic for the same user"
    assert p1.startswith("Anonymous Speaker #")
    assert "secret_speaker" not in p1
    assert "@" not in p1


def test_challenge_evaluations_mock_d1():
    mock_d1 = MagicMock()
    mock_d1.is_configured = True
    now = datetime.now(timezone.utc)
    week_start = get_current_week_start(now)

    # 3 sessions:
    # 1: duration=45, wpm=135 (optimal), fillers=0 (zero fillers)
    # 2: duration=60, wpm=150 (optimal), fillers=2
    # 3: duration=20 (too short for zero_fillers/pacing), wpm=140, fillers=0
    mock_d1.query.return_value = [
        {"id": "s1", "duration_seconds": 45.0, "wpm": 135.0, "filler_word_count": 0, "created_at": now.isoformat()},
        {"id": "s2", "duration_seconds": 60.0, "wpm": 150.0, "filler_word_count": 2, "created_at": now.isoformat()},
        {"id": "s3", "duration_seconds": 20.0, "wpm": 140.0, "filler_word_count": 0, "created_at": now.isoformat()},
    ]

    results = evaluate_user_challenges(
        user_id="test-user",
        claimed_set=set(),
        week_start=week_start,
        d1_client=mock_d1,
    )

    c_map = {c["id"]: c for c in results}

    # zero_fillers: session 1 met criteria (s3 was < 30s) -> 1 completed
    assert c_map["zero_fillers"]["is_completed"] is True
    assert c_map["zero_fillers"]["current_progress"] == 1

    # pacing_pro: session 1 & 2 met criteria (135 and 150 wpm, >= 30s) -> 2 completed
    assert c_map["pacing_pro"]["is_completed"] is True

    # consistency_streak: target is 3 sessions in current week -> 3 sessions total -> completed
    assert c_map["consistency_streak"]["is_completed"] is True
    assert c_map["consistency_streak"]["current_progress"] == 3


def test_challenge_not_completed_when_insufficient():
    mock_d1 = MagicMock()
    mock_d1.is_configured = True
    now = datetime.now(timezone.utc)
    week_start = get_current_week_start(now)

    # Only 1 session with fast pace (190 wpm) and 3 fillers
    mock_d1.query.return_value = [
        {"id": "s1", "duration_seconds": 40.0, "wpm": 190.0, "filler_word_count": 3, "created_at": now.isoformat()},
    ]

    results = evaluate_user_challenges(
        user_id="test-user",
        claimed_set=set(),
        week_start=week_start,
        d1_client=mock_d1,
    )

    c_map = {c["id"]: c for c in results}
    assert c_map["zero_fillers"]["is_completed"] is False
    assert c_map["pacing_pro"]["is_completed"] is False
    assert c_map["consistency_streak"]["is_completed"] is False
    assert c_map["consistency_streak"]["current_progress"] == 1


# ─────────────────────────────────────────────────────────────────────────────
# 2. Leaderboard Privacy Unit Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_leaderboard_privacy_pseudonyms():
    mock_d1 = MagicMock()
    mock_d1.is_configured = True
    mock_db = MagicMock()
    # Mock document retrieval to avoid network
    mock_doc = MagicMock()
    mock_doc.exists = False
    mock_db.collection.return_value.document.return_value.get.return_value = mock_doc

    now = datetime.now(timezone.utc)
    week_start = get_current_week_start(now)

    mock_d1.query.return_value = [
        {"user_id": "user-alpha", "sessions_count": 5, "avg_score": 92.5},
        {"user_id": "test-gamification-user-42", "sessions_count": 3, "avg_score": 88.0},
        {"user_id": "user-gamma", "sessions_count": 1, "avg_score": 75.0},
    ]

    board = get_weekly_leaderboard(
        current_user_id="test-gamification-user-42",
        week_start=week_start,
        d1_client=mock_d1,
        db=mock_db,
    )

    assert len(board["entries"]) == 3
    # Top rank
    top = board["entries"][0]
    assert top["rank"] == 1
    assert top["score"] == 92.5
    assert top["display_name"].startswith("Anonymous Speaker #")
    assert "email" not in str(top)
    assert "@" not in top["display_name"]

    # Current user
    cur = board["current_user_entry"]
    assert cur["rank"] == 2
    assert cur["is_current_user"] is True
    assert cur["score"] == 88.0


# ─────────────────────────────────────────────────────────────────────────────
# 3. Router Integration Tests
# ─────────────────────────────────────────────────────────────────────────────

def test_api_get_challenges(client, mock_user):
    with patch("achievements.router.evaluate_user_challenges") as mock_eval:
        mock_eval.return_value = [
            {
                "id": "zero_fillers",
                "title": "Zero Fillers Take",
                "description": "desc",
                "icon": "shield-check",
                "current_progress": 1,
                "target": 1,
                "is_completed": True,
                "is_claimed": False,
                "reward_points": 100,
            },
            {
                "id": "pacing_pro",
                "title": "Pacing Pro",
                "description": "desc",
                "icon": "speed",
                "current_progress": 0,
                "target": 1,
                "is_completed": False,
                "is_claimed": False,
                "reward_points": 150,
            },
            {
                "id": "consistency_streak",
                "title": "Consistency Streak",
                "description": "desc",
                "icon": "calendar-check",
                "current_progress": 2,
                "target": 3,
                "is_completed": False,
                "is_claimed": False,
                "reward_points": 200,
            },
        ]
        resp = client.get("/achievements/challenges")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 3
        assert data[0]["id"] == "zero_fillers"
        assert data[0]["is_completed"] is True


def test_api_claim_challenge(client, mock_user):
    with patch("achievements.router.evaluate_user_challenges") as mock_eval:
        mock_eval.return_value = [
            {
                "id": "zero_fillers",
                "title": "Zero Fillers Take",
                "description": "desc",
                "icon": "shield-check",
                "current_progress": 1,
                "target": 1,
                "is_completed": True,
                "is_claimed": False,
                "reward_points": 100,
            }
        ]
        # First claim succeeds
        resp = client.post("/achievements/challenges/zero_fillers/claim")
        assert resp.status_code == 200
        res_json = resp.json()
        assert res_json["success"] is True
        assert res_json["reward_points"] == 100
        assert res_json["total_claimed_points"] == 100

        # Second claim fails because already claimed
        resp2 = client.post("/achievements/challenges/zero_fillers/claim")
        assert resp2.status_code == 400
        assert "already claimed" in resp2.json()["detail"].lower()


def test_api_claim_uncompleted_challenge_fails(client, mock_user):
    with patch("achievements.router.evaluate_user_challenges") as mock_eval:
        mock_eval.return_value = [
            {
                "id": "pacing_pro",
                "title": "Pacing Pro",
                "description": "desc",
                "icon": "speed",
                "current_progress": 0,
                "target": 1,
                "is_completed": False,
                "is_claimed": False,
                "reward_points": 150,
            }
        ]
        resp = client.post("/achievements/challenges/pacing_pro/claim")
        assert resp.status_code == 400
        assert "not yet completed" in resp.json()["detail"].lower()


def test_api_leaderboard_opt_in_toggle(client, mock_user):
    with patch("achievements.router.get_weekly_leaderboard") as mock_lb:
        mock_lb.return_value = {
            "week_id": "2026-W42",
            "week_start": "2026-10-12T00:00:00+00:00",
            "user_opted_in": True,
            "entries": [
                {
                    "rank": 1,
                    "display_name": "Anonymous Speaker #123",
                    "score": 95.0,
                    "sessions_count": 4,
                    "is_current_user": False,
                },
                {
                    "rank": 2,
                    "display_name": "Alex (Speaker)",
                    "score": 91.0,
                    "sessions_count": 2,
                    "is_current_user": True,
                },
            ],
            "current_user_entry": {
                "rank": 2,
                "display_name": "Alex (Speaker)",
                "score": 91.0,
                "sessions_count": 2,
                "is_current_user": True,
            },
        }

        resp = client.get("/achievements/leaderboard?opt_in=true")
        assert resp.status_code == 200
        data = resp.json()
        assert data["user_opted_in"] is True
        assert len(data["entries"]) == 2
        assert data["current_user_entry"]["is_current_user"] is True
        # Verify no email leak
        assert "secret_speaker" not in resp.text
        assert "@" not in resp.text
