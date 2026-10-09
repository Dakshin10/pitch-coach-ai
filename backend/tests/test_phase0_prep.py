"""Unit tests for Phase 0: Prep (local_date, tz_offset_minutes, idempotency, and backfill script)."""
import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone, timedelta
import uuid

from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from firestore import get_db
from models import User
from schemas import StartSessionRequest
from scripts.backfill_firestore_dates import (
    compute_fields_to_update,
    _parse_created_at,
    backfill_sessions,
)
import main


class TestPhase0StartSession(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)
        self.mock_user = User(
            id="test-user-phase0",
            email="testphase0@example.com",
            full_name="Phase 0 Tester",
        )
        self.mock_db = MagicMock()

        main.app.dependency_overrides[get_current_user] = lambda: self.mock_user
        main.app.dependency_overrides[get_db] = lambda: self.mock_db

    def tearDown(self):
        main.app.dependency_overrides.clear()

    @patch("sessions.router.check_and_increment_daily_quota")
    def test_start_session_with_client_id_and_timezone(self, mock_quota):
        """Client sends session_id, local_date, and tz_offset_minutes.

        Doc must be saved with those values.
        """
        client_session_id = str(uuid.uuid4())
        today_local = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")

        # Mock existing check: doc does not exist yet
        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = False
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        payload = {
            "session_id": client_session_id,
            "mode": "interview",
            "topic_or_question": "Explain hybrid storage architecture.",
            "local_date": today_local,
            "tz_offset_minutes": 330,
        }

        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 200, resp.text)
        data = resp.json()
        self.assertEqual(data["session_id"], client_session_id)

        # Verify Firestore call
        self.mock_db.collection.assert_called_with("sessions")
        saved_dict = mock_doc_ref.set.call_args[0][0]
        self.assertEqual(saved_dict["id"], client_session_id)
        self.assertEqual(saved_dict["user_id"], self.mock_user.id)
        self.assertEqual(saved_dict["local_date"], today_local)
        self.assertEqual(saved_dict["tz_offset_minutes"], 330)

    @patch("sessions.router.check_and_increment_daily_quota")
    def test_start_session_idempotent(self, mock_quota):
        """Calling start twice with the same session_id returns 200 without creating duplicate."""
        client_session_id = str(uuid.uuid4())

        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = True  # Already exists!
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        payload = {
            "session_id": client_session_id,
            "mode": "interview",
            "topic_or_question": "Tell me about yourself.",
        }

        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["session_id"], client_session_id)
        # Quota and set should NOT be called for already existing doc
        mock_doc_ref.set.assert_not_called()
        mock_quota.assert_not_called()

    @patch("sessions.router.check_and_increment_daily_quota")
    def test_start_session_default_fallback_derivation(self, mock_quota):
        """When local_date and tz_offset_minutes are omitted, backend derives them."""
        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = False
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        payload = {
            "mode": "interview",
            "topic_or_question": "Tell me about yourself.",
        }

        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 200)
        session_id = resp.json()["session_id"]
        self.assertTrue(uuid.UUID(session_id))  # Valid UUID generated

        saved_dict = mock_doc_ref.set.call_args[0][0]
        self.assertEqual(saved_dict["tz_offset_minutes"], 0)
        self.assertIsNotNone(saved_dict["local_date"])

    def test_start_session_invalid_local_date_format(self):
        """Malformed date format must be rejected with 422."""
        payload = {
            "local_date": "2026/10/09",
            "tz_offset_minutes": 330,
        }
        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 422)

    def test_start_session_invalid_calendar_date(self):
        """Calendar dates that do not exist (e.g. Feb 31) must be rejected with 422."""
        payload = {
            "local_date": "2026-02-31",
            "tz_offset_minutes": 330,
        }
        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 422)

    def test_start_session_date_out_of_range(self):
        """A date years in past or future must be rejected with 400."""
        payload = {
            "local_date": "2020-01-01",
            "tz_offset_minutes": 0,
        }
        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 400)
        self.assertIn("acceptable range", resp.text)

    def test_start_session_invalid_tz_offset(self):
        """Timezone offset outside -720..840 must be rejected with 422."""
        payload = {
            "tz_offset_minutes": 9999,
        }
        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 422)

    def test_start_session_invalid_uuid(self):
        """Non-UUID session_id must be rejected with 422."""
        payload = {
            "session_id": "not-a-valid-uuid",
        }
        resp = self.client.post("/sessions/start", json=payload)
        self.assertEqual(resp.status_code, 422)


class TestPhase0BackfillScript(unittest.TestCase):
    def test_compute_fields_to_update_missing_both(self):
        created_dt = datetime(2026, 10, 9, 10, 0, 0, tzinfo=timezone.utc)
        doc_data = {
            "id": "s1",
            "created_at": created_dt,
            "is_analyzed": True,
            "overall_score": 85.0,
            "wpm": 130.0,
            "clarity_score": 80.0,
            "confidence_score": 90.0,
            "pause_count": 3,
            "duration_seconds": 65.0,
            "filler_word_count": 2,
        }

        # 10:00 UTC + 330 mins (5.5 hrs) = 15:30 on 2026-10-09
        updates = compute_fields_to_update(doc_data, default_tz=330)
        self.assertIsNotNone(updates)
        self.assertEqual(updates["local_date"], "2026-10-09")
        self.assertEqual(updates["tz_offset_minutes"], 330)
        self.assertIn("metrics", updates)
        self.assertEqual(updates["metrics"]["overall"], 85.0)
        self.assertEqual(updates["stage"], "done")

    def test_compute_fields_to_update_date_crossing_midnight(self):
        # 22:00 UTC + 330 mins (5.5 hrs) = next day 03:30 (2026-10-10)
        created_dt = datetime(2026, 10, 9, 22, 0, 0, tzinfo=timezone.utc)
        doc_data = {
            "id": "s2",
            "created_at": created_dt,
        }
        updates = compute_fields_to_update(doc_data, default_tz=330)
        self.assertEqual(updates["local_date"], "2026-10-10")
        self.assertEqual(updates["tz_offset_minutes"], 330)

    def test_compute_fields_to_update_already_complete_skipped(self):
        doc_data = {
            "id": "s3",
            "created_at": datetime.now(timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
            "metrics": {"overall": 80},
            "stage": "done",
        }
        updates = compute_fields_to_update(doc_data, default_tz=330)
        self.assertIsNone(updates)

    def test_compute_fields_to_update_with_force(self):
        doc_data = {
            "id": "s4",
            "created_at": datetime(2026, 10, 9, 22, 0, 0, tzinfo=timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 0,
            "metrics": {},
            "stage": "done",
        }
        updates = compute_fields_to_update(doc_data, default_tz=330, force=True)
        self.assertIsNotNone(updates)
        # forced recomputed with default_tz=330:
        self.assertEqual(updates["local_date"], "2026-10-10")
        self.assertEqual(updates["tz_offset_minutes"], 330)

    @patch("scripts.backfill_firestore_dates.get_db")
    def test_backfill_sessions_execution(self, mock_get_db):
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        doc1 = MagicMock()
        doc1.id = "doc1"
        doc1.to_dict.return_value = {
            "created_at": datetime(2026, 10, 9, 12, 0, tzinfo=timezone.utc),
        }

        doc2 = MagicMock()
        doc2.id = "doc2"
        doc2.to_dict.return_value = {
            "created_at": datetime(2026, 10, 9, 12, 0, tzinfo=timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
            "stage": "done",
            "metrics": {},
        }

        mock_db.collection.return_value.stream.return_value = [doc1, doc2]
        mock_batch = MagicMock()
        mock_db.batch.return_value = mock_batch

        scanned, updated = backfill_sessions(default_tz=330, dry_run=False)
        self.assertEqual(scanned, 2)
        self.assertEqual(updated, 1)
        mock_batch.update.assert_called_once()
        mock_batch.commit.assert_called_once()


if __name__ == "__main__":
    unittest.main()
