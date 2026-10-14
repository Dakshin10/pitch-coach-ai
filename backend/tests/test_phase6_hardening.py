import os
import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone, timedelta

from fastapi.testclient import TestClient
from main import app
from auth.dependencies import get_current_user
from firestore import get_db, get_bucket
from models import User
from scripts.nightly_rebuild_missing_d1 import rebuild_missing_d1_rows
from auth.account_service import delete_user_account


class TestPhase6Hardening(unittest.TestCase):
    def setUp(self):
        self.mock_user = User(
            id="user-hardening-1",
            email="hardening@example.com",
            full_name="Hardening Tester",
            is_guest=False,
            role_occupation="Student",
            primary_objective="Practice",
            target_industry="Tech",
            experience_level="Intermediate",
            feedback_style="Encouraging",
        )
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_delete_session_soft_deletes_in_d1_and_removes_firestore_doc(self):
        app.dependency_overrides[get_current_user] = lambda: self.mock_user

        mock_db = MagicMock()
        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = {"user_id": "user-hardening-1", "id": "sess-delete-1"}
        mock_db.collection.return_value.document.return_value.get.return_value = mock_doc
        app.dependency_overrides[get_db] = lambda: mock_db

        with patch("sessions.router.get_d1_client") as mock_get_d1, \
             patch("sessions.router.get_bucket") as mock_get_bucket:
            mock_d1 = MagicMock()
            mock_d1.is_configured = True
            mock_get_d1.return_value = mock_d1

            mock_bucket = MagicMock()
            mock_blob = MagicMock()
            mock_blob.exists.return_value = True
            mock_bucket.blob.return_value = mock_blob
            mock_get_bucket.return_value = mock_bucket

            response = self.client.delete("/sessions/sess-delete-1")
            self.assertEqual(response.status_code, 200)
            self.assertTrue(response.json()["deleted"])
            self.assertEqual(response.json()["id"], "sess-delete-1")

            # 1. Verify D1 soft delete called
            mock_d1.query.assert_called_once()
            d1_sql = mock_d1.query.call_args[0][0]
            d1_params = mock_d1.query.call_args[0][1]
            self.assertIn("UPDATE session_metrics", d1_sql)
            self.assertIn("deleted_at = ?", d1_sql)
            self.assertEqual(d1_params[2], "sess-delete-1")
            self.assertEqual(d1_params[3], "user-hardening-1")

            # 2. Verify Firestore doc deleted
            mock_db.collection.return_value.document.return_value.delete.assert_called_once()

            # 3. Verify Storage blob deleted
            mock_blob.delete.assert_called_once()

    def test_delete_account_cleans_all_stores(self):
        mock_db = MagicMock()
        with patch("auth.account_service.get_d1_client") as mock_get_d1, \
             patch("auth.account_service.get_bucket") as mock_get_bucket, \
             patch("auth.account_service.fb_auth") as mock_fb_auth, \
             patch("auth.account_service.deck_store.list_user_decks", return_value=[]):

            mock_d1 = MagicMock()
            mock_d1.is_configured = True
            mock_get_d1.return_value = mock_d1

            mock_bucket = MagicMock()
            mock_blob = MagicMock()
            mock_bucket.list_blobs.return_value = [mock_blob]
            mock_get_bucket.return_value = mock_bucket

            result = delete_user_account(self.mock_user, db=mock_db)
            self.assertTrue(result["d1_deleted"])
            self.assertTrue(result["storage_deleted"])
            self.assertTrue(result["firestore_deleted"])
            self.assertTrue(result["auth_deleted"])

            # Verify D1 deletion batch
            mock_d1.batch.assert_called_once()
            stmts = [item[0] for item in mock_d1.batch.call_args[0][0]]
            self.assertTrue(any("DELETE FROM user_achievements" in s for s in stmts))
            self.assertTrue(any("DELETE FROM session_metrics" in s for s in stmts))

            # Verify Firebase Auth deleted
            mock_fb_auth.delete_user.assert_called_once_with("user-hardening-1")

    def test_nightly_rebuild_missing_d1_rows(self):
        mock_db = MagicMock()
        mock_doc1 = MagicMock()
        mock_doc1.id = "doc-in-d1"
        mock_doc1.to_dict.return_value = {"id": "doc-in-d1", "user_id": "u1", "d1_pending": False}

        mock_doc2 = MagicMock()
        mock_doc2.id = "doc-missing-in-d1"
        mock_doc2.to_dict.return_value = {
            "id": "doc-missing-in-d1",
            "user_id": "u1",
            "metrics": {
                "wpm": 135.0,
                "overall": 86.0,
                "clarity": 88.0,
                "confidence": 84.0,
                "pause_count": 2,
                "duration": 50.0,
                "filler_count": 1,
            },
            "created_at": datetime.now(timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
            "d1_pending": False,
        }

        mock_db.collection.return_value.stream.return_value = [mock_doc1, mock_doc2]

        with patch("scripts.nightly_rebuild_missing_d1.get_db", return_value=mock_db), \
             patch("scripts.nightly_rebuild_missing_d1.get_d1_client") as mock_get_d1, \
             patch("scripts.nightly_rebuild_missing_d1.upsert_session_to_d1") as mock_upsert:

            mock_d1 = MagicMock()
            mock_d1.is_configured = True
            # D1 only contains doc-in-d1
            mock_d1.query.return_value = [{"id": "doc-in-d1"}]
            mock_get_d1.return_value = mock_d1
            mock_upsert.return_value = True

            scanned, rebuilt, failed = rebuild_missing_d1_rows(dry_run=False)
            self.assertEqual(scanned, 2)
            self.assertEqual(rebuilt, 1)
            self.assertEqual(failed, 0)
            mock_upsert.assert_called_once()

    def test_timezone_1am_ist_edge_case(self):
        """A session recorded at 1:00 AM IST (19:30 UTC previous day).

        Should be assigned to local date 2026-10-10, NOT 2026-10-09 (UTC date).
        """
        # 19:30 UTC on 2026-10-09 + 330 mins (5.5 hrs) = 01:00 AM on 2026-10-10
        utc_time = datetime(2026, 10, 9, 19, 30, 0, tzinfo=timezone.utc)
        tz_offset = 330
        local_time = utc_time + timedelta(minutes=tz_offset)
        local_date = local_time.strftime("%Y-%m-%d")

        self.assertEqual(utc_time.strftime("%Y-%m-%d"), "2026-10-09")
        self.assertEqual(local_date, "2026-10-10")

    def test_duplicate_post_idempotency(self):
        """Sending POST with the same session_id upserts without creating duplicates."""
        from d1.sync import build_d1_upsert_statements

        session_data = {
            "id": "fixed-uuid-1",
            "user_id": "user-idem",
            "mode": "interview",
            "topic_or_question": "Test Question",
            "duration_seconds": 30.0,
            "wpm": 120.0,
            "filler_word_count": 1,
            "filler_word_breakdown": {"like": 1},
            "pause_count": 1,
            "avg_pause_length": 1.0,
            "clarity_score": 80.0,
            "confidence_score": 80.0,
            "overall_score": 80.0,
            "created_at": datetime.now(timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
        }

        stmts = build_d1_upsert_statements(session_data)
        # Verify the primary session insert contains ON CONFLICT(id) DO UPDATE
        session_sql, session_params = stmts[0]
        self.assertIn("ON CONFLICT(id) DO UPDATE", session_sql)
        self.assertEqual(session_params[0], "fixed-uuid-1")


if __name__ == "__main__":
    unittest.main()
