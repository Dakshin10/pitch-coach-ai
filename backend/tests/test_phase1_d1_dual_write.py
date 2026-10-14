"""Unit tests for Phase 1: D1 client, dual-write in POST /sessions, backfill, and pending rebuild."""
import io
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timezone
import uuid

import httpx
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from d1.d1_client import (
    D1Client,
    D1ConfigurationError,
    D1ConnectionError,
    D1QueryError,
)
from d1.sync import (
    build_d1_upsert_statements,
    sync_firestore_session_to_d1,
    upsert_session_to_d1,
)
from firestore import get_db
from models import User
from scripts.backfill_firestore_to_d1 import backfill_firestore_to_d1
from scripts.rebuild_d1_pending import rebuild_pending_sessions
import main


class TestD1Client(unittest.TestCase):
    def test_unconfigured_client_raises_configuration_error(self):
        client = D1Client(account_id="", database_id="", api_token="")
        self.assertFalse(client.is_configured)
        with self.assertRaises(D1ConfigurationError):
            _ = client.endpoint_url

    def test_query_success_with_mock_http(self):
        mock_http = MagicMock()
        mock_response = MagicMock()
        mock_response.is_success = True
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "result": [
                {
                    "results": [{"id": "s1", "overall_score": 88.5}],
                    "meta": {"changes": 0},
                }
            ],
            "errors": [],
        }
        mock_http.post.return_value = mock_response

        client = D1Client(
            account_id="acc123",
            database_id="db123",
            api_token="token123",
            http_client=mock_http,
        )
        rows = client.query("SELECT * FROM session_metrics WHERE user_id = ?", ["u1"])
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["id"], "s1")
        self.assertEqual(rows[0]["overall_score"], 88.5)

    def test_query_retry_on_500_then_success(self):
        mock_http = MagicMock()

        fail_resp = MagicMock()
        fail_resp.is_success = False
        fail_resp.status_code = 500

        success_resp = MagicMock()
        success_resp.is_success = True
        success_resp.status_code = 200
        success_resp.json.return_value = {
            "success": True,
            "result": [{"results": [{"cnt": 5}], "meta": {}}],
        }

        mock_http.post.side_effect = [fail_resp, success_resp]

        client = D1Client(
            account_id="acc123",
            database_id="db123",
            api_token="token123",
            max_retries=2,
            http_client=mock_http,
        )
        rows = client.query("SELECT COUNT(*) as cnt FROM session_metrics")
        self.assertEqual(rows[0]["cnt"], 5)
        self.assertEqual(mock_http.post.call_count, 2)

    def test_query_raises_query_error_on_sql_failure(self):
        mock_http = MagicMock()
        mock_response = MagicMock()
        mock_response.is_success = True
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": False,
            "errors": [{"code": 1001, "message": "no such table: bad_table"}],
        }
        mock_http.post.return_value = mock_response

        client = D1Client(
            account_id="acc123",
            database_id="db123",
            api_token="token123",
            http_client=mock_http,
        )
        with self.assertRaises(D1QueryError) as ctx:
            client.query("SELECT * FROM bad_table")
        self.assertIn("no such table", str(ctx.exception))

    def test_batch_statements_formatting(self):
        mock_http = MagicMock()
        mock_response = MagicMock()
        mock_response.is_success = True
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "success": True,
            "result": [
                {"results": [], "meta": {"changes": 1}},
                {"results": [], "meta": {"changes": 1}},
            ],
        }
        mock_http.post.return_value = mock_response

        client = D1Client(
            account_id="acc123",
            database_id="db123",
            api_token="token123",
            http_client=mock_http,
        )
        res = client.batch([
            ("INSERT INTO session_metrics (id) VALUES (?)", ["s1"]),
            ("INSERT INTO session_fillers (session_id, filler_word) VALUES (?, ?)", ["s1", "um"]),
        ])
        self.assertEqual(len(res), 2)
        called_payload = mock_http.post.call_args[1]["json"]
        self.assertEqual(len(called_payload), 2)
        self.assertEqual(called_payload[0]["sql"], "INSERT INTO session_metrics (id) VALUES (?)")
        self.assertEqual(called_payload[1]["params"], ["s1", "um"])


class TestPhase1DualWrite(unittest.TestCase):
    def test_build_d1_upsert_statements_shape(self):
        session_data = {
            "id": "s-1234",
            "user_id": "u-5678",
            "mode": "presentation",
            "topic_or_question": "Pitch Deck Rehearsal",
            "duration_seconds": 120.0,
            "wpm": 140.0,
            "filler_word_count": 4,
            "filler_word_breakdown": {"um": 3, "like": 1},
            "pause_count": 5,
            "avg_pause_length": 1.2,
            "clarity_score": 90.0,
            "confidence_score": 85.0,
            "overall_score": 87.5,
            "created_at": datetime(2026, 10, 9, 12, 0, tzinfo=timezone.utc),
            "local_date": "2026-10-09",
            "tz_offset_minutes": 330,
            "stage": "done",
            "is_analyzed": True,
        }
        stmts = build_d1_upsert_statements(session_data)
        # 1 metrics statement + 2 filler statements
        self.assertEqual(len(stmts), 3)

        metrics_sql, metrics_params = stmts[0]
        self.assertIn("INSERT INTO session_metrics", metrics_sql)
        self.assertIn("ON CONFLICT(id) DO UPDATE", metrics_sql)
        self.assertEqual(metrics_params[0], "s-1234")
        self.assertEqual(metrics_params[1], "u-5678")
        self.assertEqual(metrics_params[11], 87.5)  # overall_score
        self.assertEqual(metrics_params[12], "analyzed")  # status
        self.assertEqual(metrics_params[14], "2026-10-09")  # local_date
        self.assertEqual(metrics_params[15], 330)  # tz_offset_minutes

        # Filler statements
        filler_words = {s[1][1]: s[1][2] for s in stmts[1:]}
        self.assertEqual(filler_words, {"um": 3, "like": 1})

    def test_upsert_session_to_d1_calls_client_batch(self):
        mock_d1 = MagicMock()
        mock_d1.is_configured = True
        data = {
            "id": "s-100",
            "user_id": "u-100",
            "filler_word_breakdown": {"so": 2},
        }
        ok = upsert_session_to_d1(data, d1_client=mock_d1)
        self.assertTrue(ok)
        mock_d1.batch.assert_called_once()


class TestPhase1PostSessionsEndpoint(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)
        self.mock_user = User(
            id="test-uid-123",
            email="test@pitchcoach.com",
            full_name="Dual Write User",
        )
        self.mock_db = MagicMock()

        main.app.dependency_overrides[get_current_user] = lambda: self.mock_user
        main.app.dependency_overrides[get_db] = lambda: self.mock_db

    def tearDown(self):
        main.app.dependency_overrides.clear()

    @patch("sessions.router.analyze_audio")
    @patch("sessions.router.upsert_session_to_d1")
    @patch("sessions.router.check_and_increment_daily_quota")
    def test_post_sessions_dual_write_success(self, mock_quota, mock_upsert_d1, mock_analyze):
        """POST /sessions analyzes audio, saves Firestore first, then upserts D1 and returns metrics."""
        mock_upsert_d1.return_value = True

        mock_analysis = MagicMock()
        mock_analysis.transcript = "This is our revolutionary pitch."
        mock_analysis.duration_seconds = 45.0
        mock_analysis.wpm = 135.0
        mock_analysis.clarity_score = 92.0
        mock_analysis.confidence_score = 88.0
        mock_analysis.overall_score = 90.0
        mock_analysis.filler.total_count = 1
        mock_analysis.filler.breakdown = {"basically": 1}
        mock_analysis.pauses.count = 2
        mock_analysis.pauses.avg_length = 0.8
        mock_analysis.ai_feedback = []
        mock_analyze.return_value = mock_analysis

        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = False
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        client_uuid = str(uuid.uuid4())
        audio_bytes = b"FAKE_AUDIO_DATA_FOR_TESTING"

        resp = self.client.post(
            "/sessions",
            data={
                "session_id": client_uuid,
                "mode": "presentation",
                "topic_or_question": "Series A Pitch",
                "duration_seconds": 45.0,
                "local_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
                "tz_offset_minutes": 330,
            },
            files={"audio_file": ("test.m4a", io.BytesIO(audio_bytes), "audio/mp4")},
        )
        self.assertEqual(resp.status_code, 200, resp.text)
        result = resp.json()

        # Verified return values
        self.assertEqual(result["id"], client_uuid)
        self.assertEqual(result["overall_score"], 90.0)
        self.assertEqual(result["wpm"], 135.0)

        # Firestore written first with metrics snapshot
        mock_doc_ref.set.assert_called_once()
        saved_doc = mock_doc_ref.set.call_args[0][0]
        self.assertEqual(saved_doc["user_id"], self.mock_user.id)
        self.assertEqual(saved_doc["metrics"]["overall"], 90.0)
        self.assertEqual(saved_doc["stage"], "done")
        self.assertFalse(saved_doc["d1_pending"])

        # D1 upsert called with doc data
        mock_upsert_d1.assert_called_once()
        self.assertEqual(mock_upsert_d1.call_args[0][0]["id"], client_uuid)

    @patch("sessions.router.analyze_audio")
    @patch("sessions.router.upsert_session_to_d1")
    @patch("sessions.router.check_and_increment_daily_quota")
    def test_post_sessions_d1_failure_sets_pending_and_succeeds(self, mock_quota, mock_upsert_d1, mock_analyze):
        """When D1 write fails, Firestore marks d1_pending=true, and request still returns HTTP 200."""
        mock_upsert_d1.return_value = False  # D1 down!

        mock_analysis = MagicMock()
        mock_analysis.transcript = "Test speech"
        mock_analysis.duration_seconds = 10.0
        mock_analysis.wpm = 120.0
        mock_analysis.clarity_score = 80.0
        mock_analysis.confidence_score = 80.0
        mock_analysis.overall_score = 80.0
        mock_analysis.filler.total_count = 0
        mock_analysis.filler.breakdown = {}
        mock_analysis.pauses.count = 0
        mock_analysis.pauses.avg_length = 0.0
        mock_analysis.ai_feedback = []
        mock_analyze.return_value = mock_analysis

        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = False
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        client_uuid = str(uuid.uuid4())
        resp = self.client.post(
            "/sessions",
            data={
                "session_id": client_uuid,
                "mode": "interview",
                "topic_or_question": "Tell me about yourself",
                "duration_seconds": 10.0,
            },
            files={"audio_file": ("test.m4a", io.BytesIO(b"AUDIO_DATA"), "audio/mp4")},
        )
        self.assertEqual(resp.status_code, 200)

        # Firestore updated to d1_pending=True
        mock_doc_ref.update.assert_called_with({"d1_pending": True})

    def test_post_sessions_idempotent_duplicate(self):
        """Duplicate POST with same session_id that was already analyzed returns existing metrics."""
        client_uuid = str(uuid.uuid4())
        mock_doc_ref = MagicMock()
        mock_doc_ref.get.return_value.exists = True
        mock_doc_ref.get.return_value.to_dict.return_value = {
            "id": client_uuid,
            "user_id": self.mock_user.id,
            "mode": "interview",
            "topic_or_question": "Existing question",
            "duration_seconds": 30.0,
            "wpm": 140.0,
            "filler_word_count": 0,
            "filler_word_breakdown": {},
            "pause_count": 1,
            "avg_pause_length": 0.5,
            "clarity_score": 95.0,
            "confidence_score": 95.0,
            "overall_score": 95.0,
            "ai_feedback": [],
            "created_at": datetime.now(timezone.utc),
            "is_analyzed": True,
            "analysis_failed": False,
        }
        self.mock_db.collection.return_value.document.return_value = mock_doc_ref

        resp = self.client.post(
            "/sessions",
            data={"session_id": client_uuid},
            files={"audio_file": ("test.m4a", io.BytesIO(b"AUDIO_DATA"), "audio/mp4")},
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["overall_score"], 95.0)


class TestPhase1BackfillAndRebuild(unittest.TestCase):
    def setUp(self):
        from scripts.backfill_firestore_to_d1 import CHECKPOINT_FILE
        if os.path.exists(CHECKPOINT_FILE):
            os.remove(CHECKPOINT_FILE)

    def tearDown(self):
        from scripts.backfill_firestore_to_d1 import CHECKPOINT_FILE
        if os.path.exists(CHECKPOINT_FILE):
            os.remove(CHECKPOINT_FILE)

    @patch("scripts.backfill_firestore_to_d1.get_d1_client")
    @patch("scripts.backfill_firestore_to_d1.get_db")
    def test_backfill_firestore_to_d1(self, mock_get_db, mock_get_d1):
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db

        mock_d1 = MagicMock()
        mock_d1.is_configured = True
        mock_get_d1.return_value = mock_d1

        doc = MagicMock()
        doc.id = "s-backfill-1"
        doc.to_dict.return_value = {
            "id": "s-backfill-1",
            "user_id": "u1",
            "is_analyzed": True,
            "overall_score": 85.0,
            "created_at": datetime.now(timezone.utc),
        }
        mock_db.collection.return_value.order_by.return_value.stream.return_value = [doc]

        scanned, synced = backfill_firestore_to_d1(batch_size=10, dry_run=False)
        self.assertEqual(scanned, 1)
        self.assertEqual(synced, 1)
        mock_d1.batch.assert_called_once()

    @patch("scripts.rebuild_d1_pending.get_d1_client")
    @patch("scripts.rebuild_d1_pending.upsert_session_to_d1")
    @patch("scripts.rebuild_d1_pending.get_db")
    def test_rebuild_d1_pending(self, mock_get_db, mock_upsert, mock_get_d1):
        mock_db = MagicMock()
        mock_get_db.return_value = mock_db
        mock_d1 = MagicMock()
        mock_d1.is_configured = True
        mock_get_d1.return_value = mock_d1
        mock_upsert.return_value = True

        doc = MagicMock()
        doc.id = "pending-1"
        doc.to_dict.return_value = {
            "id": "pending-1",
            "user_id": "u1",
            "d1_pending": True,
            "is_analyzed": True,
        }
        mock_db.collection.return_value.where.return_value.limit.return_value.stream.return_value = [doc]

        found, succeeded, failed = rebuild_pending_sessions(dry_run=False)
        self.assertEqual(found, 1)
        self.assertEqual(succeeded, 1)
        self.assertEqual(failed, 0)
        mock_db.collection.return_value.document.return_value.update.assert_called_with({"d1_pending": False})


if __name__ == "__main__":
    unittest.main()
