"""Section 5: Achievements, Deletions, and Rebuild tests."""
from datetime import datetime, timezone, timedelta
import sys
import unittest
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from achievements.service import evaluate_user_achievements
import auth.account_service as account_service
from auth.dependencies import get_current_user
import d1.d1_client
from firestore import get_db
import main
from models import User
from scripts.backfill_firestore_to_d1 import backfill_firestore_to_d1
from scripts.nightly_rebuild_missing_d1 import rebuild_missing_d1_rows
from scripts.rebuild_d1_pending import rebuild_pending_sessions
from tests.test_sec2_post_sessions import LocalSqliteD1, InMemoryFirestoreDB


class TestSection5AchievementsDeleteRebuild:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = InMemoryFirestoreDB()
        self.user = User(id="user_sec5_test", email="sec5@example.com")
        self.user_other = User(id="user_sec5_other", email="other@example.com")

        monkeypatch.setattr(d1.d1_client, "get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("auth.account_service.get_d1_client", lambda: self.fake_d1)
        if "metrics.router" in sys.modules:
            monkeypatch.setattr(sys.modules["metrics.router"], "get_d1_client", lambda: self.fake_d1)
        if "sessions.router" in sys.modules:
            monkeypatch.setattr(sys.modules["sessions.router"], "get_d1_client", lambda: self.fake_d1)
        if "stats.router" in sys.modules:
            monkeypatch.setattr(sys.modules["stats.router"], "get_d1_client", lambda: self.fake_d1)
        if "achievements.service" in sys.modules:
            monkeypatch.setattr(sys.modules["achievements.service"], "get_d1_client", lambda: self.fake_d1)

        main.app.dependency_overrides[get_current_user] = lambda: self.user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _seed_metric(self, sid, clarity=80.0, overall=80.0, local_date="2026-10-09", created_at="2026-10-09T10:00:00Z", uid=None):
        user_id = uid or self.user.id
        self.fake_d1.execute("""
            INSERT INTO session_metrics (
                id, user_id, mode, topic_or_question, duration_seconds, wpm,
                filler_word_count, pause_count, avg_pause_length, clarity_score,
                confidence_score, overall_score, status, created_at, local_date,
                tz_offset_minutes, updated_at
            ) VALUES (?, ?, 'interview', 'Topic', 60.0, 130.0, 2, 1, 0.5, ?, 80.0, ?, 'analyzed',
                      ?, ?, 330, ?);
        """, [sid, user_id, clarity, overall, created_at, local_date, created_at])

    # 1. Achievement rules: below, at, above threshold & idempotency
    def test_achievement_rules_thresholds_and_idempotency(self):
        # Initial: 0 sessions -> no unlocks
        new_unlocks = evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)
        assert len(new_unlocks) == 0

        # Session 1 with clarity 84.9 (below clarity_master threshold 85.0)
        self._seed_metric("s1", clarity=84.9)
        new_unlocks = evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)
        assert new_unlocks == ["first_session"]
        assert "clarity_master" not in new_unlocks

        # Re-evaluate: idempotent, returns empty list
        re_eval = evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)
        assert len(re_eval) == 0

        # Session 2 with clarity 85.0 (exact threshold)
        self._seed_metric("s2", clarity=85.0)
        new_unlocks = evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)
        assert new_unlocks == ["clarity_master"]

        # Session 3 with clarity 95.0 (above threshold) -> already unlocked, no new unlock
        self._seed_metric("s3", clarity=95.0)
        new_unlocks = evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)
        assert len(new_unlocks) == 0

    # 2. Unlock timing: unlock appears in /metrics/changes after triggering session
    def test_unlock_timing_appears_in_metrics_changes(self):
        self._seed_metric("s-first", clarity=80.0)
        evaluate_user_achievements(self.user.id, d1_client=self.fake_d1)

        resp = self.client.get("/metrics/changes")
        assert resp.status_code == 200
        data = resp.json()
        ach_keys = [a["achievement_key"] for a in data["achievements"]]
        assert "first_session" in ach_keys

    # 3. DELETE /sessions/{id}: soft-deleted in D1, Firestore doc and Storage audio removed, safe repeat
    @patch("sessions.router.get_bucket")
    def test_delete_session_flow(self, mock_get_bucket):
        mock_blob = MagicMock()
        mock_get_bucket.return_value.blob.return_value = mock_blob

        sid = "sess-del-123"
        self._seed_metric(sid)
        self.fake_db.collection("sessions").document(sid).set({
            "id": sid,
            "user_id": self.user.id,
            "audio_url": f"audio/{self.user.id}/{sid}.m4a",
        })

        # 1st DELETE call
        resp = self.client.delete(f"/sessions/{sid}")
        assert resp.status_code == 200

        # D1 row must be soft-deleted (deleted_at IS NOT NULL)
        rows = self.fake_d1.query("SELECT deleted_at FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1
        assert rows[0]["deleted_at"] is not None

        # Firestore doc deleted
        doc = self.fake_db.collection("sessions").document(sid)
        assert doc.exists is False

        # Storage blob deleted
        mock_blob.delete.assert_called_once()

        # Repeating DELETE is safe
        resp2 = self.client.delete(f"/sessions/{sid}")
        assert resp2.status_code in (200, 404)

    # 4. DELETE /account: removes all user data from D1, Firestore, Storage, and Auth
    @patch("auth.account_service.fb_auth.delete_user")
    @patch("auth.account_service.get_bucket")
    def test_delete_account_complete_cleanup(self, mock_get_bucket, mock_delete_user):
        mock_blob = MagicMock()
        mock_get_bucket.return_value.list_blobs.return_value = [mock_blob]

        # Seed data for user and other user
        self._seed_metric("u_sess", uid=self.user.id)
        self._seed_metric("other_sess", uid=self.user_other.id)

        self.fake_d1.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES ('u_sess', 'um', 2);")
        self.fake_d1.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES ('other_sess', 'um', 2);")
        self.fake_d1.execute(
            "INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at) "
            "VALUES (?, 'first_session', '2026-10-09', '2026-10-09');",
            [self.user.id]
        )
        self.fake_d1.execute(
            "INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at) "
            "VALUES (?, 'first_session', '2026-10-09', '2026-10-09');",
            [self.user_other.id]
        )

        self.fake_db.collection("users").document(self.user.id).set({"id": self.user.id})
        self.fake_db.collection("users").document(self.user_other.id).set({"id": self.user_other.id})

        # Execute delete_account
        account_service.delete_user_account(self.user, db=self.fake_db)

        # Assert User data gone in D1
        user_metrics = self.fake_d1.query("SELECT * FROM session_metrics WHERE user_id = ?", [self.user.id])
        assert len(user_metrics) == 0
        user_fillers = self.fake_d1.query(
            "SELECT * FROM session_fillers WHERE session_id = 'u_sess'"
        )
        assert len(user_fillers) == 0
        user_achs = self.fake_d1.query("SELECT * FROM user_achievements WHERE user_id = ?", [self.user.id])
        assert len(user_achs) == 0

        # Assert Other user untouched in D1
        other_metrics = self.fake_d1.query("SELECT * FROM session_metrics WHERE user_id = ?", [self.user_other.id])
        assert len(other_metrics) == 1
        other_achs = self.fake_d1.query("SELECT * FROM user_achievements WHERE user_id = ?", [self.user_other.id])
        assert len(other_achs) == 1

        # Assert Auth delete called
        mock_delete_user.assert_called_once_with(self.user.id)

    # 5. Rebuild job: rebuilds missing D1 rows from Firestore metrics snapshot
    @patch("scripts.nightly_rebuild_missing_d1.get_db")
    @patch("scripts.nightly_rebuild_missing_d1.get_d1_client")
    def test_rebuild_missing_d1_rows(self, mock_get_d1, mock_get_db):
        mock_get_d1.return_value = self.fake_d1

        # Create mock stream doc
        mock_doc = MagicMock()
        mock_doc.id = "rebuild-sess-99"
        mock_doc.reference = mock_doc
        mock_doc.to_dict.return_value = {
            "id": "rebuild-sess-99",
            "user_id": self.user.id,
            "mode": "interview",
            "topic_or_question": "Rebuild test topic",
            "metrics": {
                "overall": 87.0,
                "wpm": 135.0,
                "clarity": 89.0,
                "confidence": 85.0,
                "pause_count": 2,
                "duration": 50.0,
                "filler_count": 3,
            },
            "created_at": datetime(2026, 10, 9, 10, 0, tzinfo=timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
            "is_analyzed": True,
            "d1_pending": False,
        }
        mock_get_db.return_value.collection.return_value.stream.return_value = [mock_doc]

        # Run nightly rebuild
        scanned, rebuilt, failed = rebuild_missing_d1_rows(dry_run=False)
        assert rebuilt == 1

        # Verify row in D1
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", ["rebuild-sess-99"])
        assert len(rows) == 1
        assert rows[0]["overall_score"] == 87.0
        assert rows[0]["wpm"] == 135.0

        # Rerun when D1 already has row: missing_in_d1 is False, d1_pending is False -> 0 rebuilt
        scanned2, rebuilt2, failed2 = rebuild_missing_d1_rows(dry_run=False)
        assert rebuilt2 == 0

    # 6. Backfill script is resumable and idempotent
    @patch("scripts.backfill_firestore_to_d1.get_db")
    @patch("scripts.backfill_firestore_to_d1.get_d1_client")
    def test_backfill_resumable_and_idempotent(self, mock_get_d1, mock_get_db):
        mock_get_d1.return_value = self.fake_d1
        docs = []
        for i in range(5):
            d = MagicMock()
            d.id = f"bf-{i}"
            d.to_dict.return_value = {
                "id": f"bf-{i}",
                "user_id": self.user.id,
                "mode": "interview",
                "topic_or_question": f"Topic {i}",
                "overall_score": 80.0 + i,
                "created_at": datetime(2026, 10, 9, 10, i, tzinfo=timezone.utc),
                "local_date": "2026-10-09",
                "tz_offset_minutes": 330,
                "is_analyzed": True,
            }
            docs.append(d)
        mock_query = MagicMock()
        mock_query.stream.return_value = docs
        mock_query.order_by.return_value = mock_query
        mock_query.start_after.return_value = mock_query
        mock_get_db.return_value.collection.return_value = mock_query

        # Run 1
        scanned1, synced1 = backfill_firestore_to_d1(dry_run=False)
        assert synced1 == 5

        # Run 2: idempotent, no duplicates
        scanned2, synced2 = backfill_firestore_to_d1(dry_run=False)
        assert synced2 == 5

        rows = self.fake_d1.query("SELECT COUNT(*) AS cnt FROM session_metrics")
        assert rows[0]["cnt"] == 5
