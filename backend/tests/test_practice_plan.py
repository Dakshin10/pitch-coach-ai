"""
Tests for Personalized Practice Plan (Feature 6).
Verifies:
1. New user with no history sees sensible default plan.
2. Seeded history with high fillers targets filler reduction drills.
3. Seeded history with abnormal WPM targets pacing drills.
4. Seeded history with excessive pauses targets transition flow drills.
5. Drill completion evaluation and explicit completion endpoint.
"""
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock

from auth.dependencies import get_current_user
from firestore import get_db
import main
from models import User
from practice_plan.service import (
    _diagnose_metrics,
    _evaluate_drill_completion,
    _generate_targeted_drills,
    get_practice_plan,
    mark_drill_completed,
)
from practice_plan.schemas import PracticeDrill

client = TestClient(main.app)


class TestPracticePlan:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.mock_user = User(id="user_plan_test", email="plan@example.com")
        self.fake_sessions = []
        self.completed_drills = []

        # Mock Firestore
        self.mock_db = MagicMock()
        user_doc_mock = MagicMock()
        user_doc_mock.exists = True
        user_doc_mock.to_dict.return_value = {"completed_drills": self.completed_drills}
        self.mock_db.collection.return_value.document.return_value.get.return_value = user_doc_mock

        main.app.dependency_overrides[get_current_user] = lambda: self.mock_user
        main.app.dependency_overrides[get_db] = lambda: self.mock_db
        yield
        main.app.dependency_overrides.clear()

    def test_new_user_sensible_default_plan(self, monkeypatch):
        """A new user with no history sees a sensible default plan with 3 drills."""
        monkeypatch.setattr(
            "practice_plan.service._fetch_last_n_sessions",
            lambda user_id, **kw: [],
        )

        resp = client.get("/practice-plan")
        assert resp.status_code == 200
        data = resp.json()

        assert data["is_default_plan"] is True
        assert len(data["drills"]) == 3
        drill_ids = [d["id"] for d in data["drills"]]
        assert "drill_default_zero_fillers" in drill_ids
        assert "drill_default_pacing_metronome" in drill_ids
        assert "drill_default_controlled_pauses" in drill_ids

    def test_seeded_high_fillers_targets_filler_drills(self, monkeypatch):
        """Seeded sessions with high fillers target filler-reduction drills."""
        high_filler_sessions = [
            {
                "id": f"sess-{i}",
                "duration_seconds": 60.0,
                "wpm": 135.0,
                "filler_word_count": 6,  # ~4.4 fillers per 100 words
                "pause_count": 1,
                "clarity_score": 65.0,
                "confidence_score": 75.0,
                "overall_score": 70.0,
            }
            for i in range(5)
        ]
        monkeypatch.setattr(
            "practice_plan.service._fetch_last_n_sessions",
            lambda user_id, **kw: high_filler_sessions,
        )

        resp = client.get("/practice-plan")
        assert resp.status_code == 200
        data = resp.json()

        assert data["is_default_plan"] is False
        assert data["diagnosis"]["weakest_metric"] == "fillers"
        assert data["diagnosis"]["avg_fillers_per_100"] > 3.0

        drill_ids = [d["id"] for d in data["drills"]]
        assert "drill_zero_fillers_30s" in drill_ids
        assert any("filler" in d["target_metric"] for d in data["drills"])

    def test_seeded_abnormal_wpm_targets_pacing_drills(self, monkeypatch):
        """Seeded sessions with rapid pacing (190 WPM) target cadence drills."""
        rushed_sessions = [
            {
                "id": f"sess-{i}",
                "duration_seconds": 60.0,
                "wpm": 190.0,  # Far above 160 band
                "filler_word_count": 0,
                "pause_count": 1,
                "clarity_score": 85.0,
                "confidence_score": 80.0,
                "overall_score": 78.0,
            }
            for i in range(5)
        ]
        monkeypatch.setattr(
            "practice_plan.service._fetch_last_n_sessions",
            lambda user_id, **kw: rushed_sessions,
        )

        resp = client.get("/practice-plan")
        assert resp.status_code == 200
        data = resp.json()

        assert data["diagnosis"]["weakest_metric"] == "wpm"
        assert data["diagnosis"]["avg_wpm"] >= 180.0
        drill_ids = [d["id"] for d in data["drills"]]
        assert "drill_metronome_pacing_60s" in drill_ids

    def test_seeded_high_pauses_targets_pause_drills(self, monkeypatch):
        """Seeded sessions with long pauses target transition flow drills."""
        stalled_sessions = [
            {
                "id": f"sess-{i}",
                "duration_seconds": 45.0,
                "wpm": 130.0,
                "filler_word_count": 0,
                "pause_count": 6,  # 8 pauses per minute
                "clarity_score": 68.0,
                "confidence_score": 65.0,
                "overall_score": 66.0,
            }
            for i in range(5)
        ]
        monkeypatch.setattr(
            "practice_plan.service._fetch_last_n_sessions",
            lambda user_id, **kw: stalled_sessions,
        )

        resp = client.get("/practice-plan")
        assert resp.status_code == 200
        data = resp.json()

        assert data["diagnosis"]["weakest_metric"] == "pauses"
        drill_ids = [d["id"] for d in data["drills"]]
        assert "drill_transition_flow_45s" in drill_ids

    def test_drill_completion_evaluation_and_endpoint(self, monkeypatch):
        """Matching practice session satisfies criteria and marks drill complete."""
        drill = PracticeDrill(
            id="drill_zero_fillers_30s",
            title="30 Seconds, Zero Fillers",
            description="30s without fillers",
            target_metric="fillers",
            target_duration_seconds=30,
            success_criteria={"max_filler_count": 0, "min_duration_seconds": 25.0},
            reason="Drill test",
        )

        # Successful session: 30s, 0 fillers -> Pass
        session_good = {"duration_seconds": 32.0, "filler_word_count": 0, "wpm": 140.0}
        assert _evaluate_drill_completion(drill, session_good) is True

        # Failed session: 30s, 2 fillers -> Fail
        session_bad = {"duration_seconds": 32.0, "filler_word_count": 2, "wpm": 140.0}
        assert _evaluate_drill_completion(drill, session_bad) is False

        # Endpoint test: complete drill
        resp = client.post(
            "/practice-plan/complete",
            json={"drill_id": "drill_zero_fillers_30s"},
        )
        assert resp.status_code == 200
        assert resp.json()["is_completed"] is True
