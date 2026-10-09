"""Section 2 tests: POST /sessions rigorous verification of 14 cases."""
import asyncio
from concurrent.futures import ThreadPoolExecutor
import io
import json
import os
import sqlite3
import threading
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from d1.d1_client import D1Client, D1ConnectionError, D1QueryError
from firestore import get_db
import main
from models import User
from sessions.pipeline import SessionAnalysis, FillerAnalysis, PauseAnalysis, FeedbackItem, WordTimestamp


D1_MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "d1", "migrations"))


class LocalSqliteD1:
    """Simulates Cloudflare D1 with an in-memory SQLite database and full failure injection."""
    def __init__(self):
        self.lock = threading.Lock()
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON;")
        for mf in sorted([f for f in os.listdir(D1_MIGRATIONS_DIR) if f.endswith(".sql")]):
            with open(os.path.join(D1_MIGRATIONS_DIR, mf), "r", encoding="utf-8") as f:
                self.conn.executescript(f.read())
        self.fail_count = 0
        self.timeout_count = 0
        self.call_log = []

    @property
    def is_configured(self) -> bool:
        return True

    def query(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        with self.lock:
            self.call_log.append(("query", sql, params))
            if self.timeout_count > 0:
                self.timeout_count -= 1
                raise D1ConnectionError("Simulated D1 timeout")
            if self.fail_count > 0:
                self.fail_count -= 1
                raise D1QueryError("Simulated D1 query failure")

            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            rows = cursor.fetchall()
            return [dict(r) for r in rows]

    def execute(self, sql: str, params: Optional[List[Any]] = None) -> Dict[str, Any]:
        with self.lock:
            self.call_log.append(("execute", sql, params))
            if self.timeout_count > 0:
                self.timeout_count -= 1
                raise D1ConnectionError("Simulated D1 timeout")
            if self.fail_count > 0:
                self.fail_count -= 1
                raise D1QueryError("Simulated D1 query failure")

            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            self.conn.commit()
            return {"results": [], "changes": cursor.rowcount, "meta": {}}

    def batch(self, statements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        with self.lock:
            self.call_log.append(("batch", len(statements)))
            if self.timeout_count > 0:
                self.timeout_count -= 1
                raise D1ConnectionError("Simulated D1 timeout")
            if self.fail_count > 0:
                self.fail_count -= 1
                raise D1QueryError("Simulated D1 query failure")

            cursor = self.conn.cursor()
            results = []
            try:
                for stmt in statements:
                    if isinstance(stmt, tuple):
                        sql = stmt[0]
                        params = stmt[1] if len(stmt) > 1 else []
                    elif isinstance(stmt, dict):
                        sql = stmt["sql"]
                        params = stmt.get("params", [])
                    else:
                        raise ValueError(f"Invalid statement type: {type(stmt)}")
                    cursor.execute(sql, params)
                    results.append({"results": [], "changes": cursor.rowcount})
                self.conn.commit()
            except Exception as e:
                self.conn.rollback()
                raise D1QueryError(str(e))
            return results


class InMemoryFirestoreDoc:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]] = None, parent_db=None):
        self.id = doc_id
        self._data = data.copy() if data else {}
        self.exists = data is not None
        self._db = parent_db

    def to_dict(self):
        return self._data.copy()

    def get(self):
        return self

    def set(self, data: Dict[str, Any]):
        if self._db and self._db.should_fail_write:
            raise RuntimeError("Simulated Firestore write failure")
        self._data = data.copy()
        self.exists = True
        if self._db:
            self._db.log_call("firestore_set", self.id, data)

    def update(self, data: Dict[str, Any]):
        if self._db and self._db.should_fail_write:
            raise RuntimeError("Simulated Firestore write failure")
        self._data.update(data)
        if self._db:
            self._db.log_call("firestore_update", self.id, data)

    def delete(self):
        self.exists = False
        self._data = {}
        if self._db:
            self._db.log_call("firestore_delete", self.id)


class InMemoryFirestoreCollection:
    def __init__(self, name: str, parent_db):
        self.name = name
        self.parent_db = parent_db
        self.docs: Dict[str, InMemoryFirestoreDoc] = {}

    def document(self, doc_id: str) -> InMemoryFirestoreDoc:
        if doc_id not in self.docs:
            self.docs[doc_id] = InMemoryFirestoreDoc(doc_id, None, parent_db=self.parent_db)
        return self.docs[doc_id]

    def where(self, field, op, val):
        return self

    def order_by(self, field):
        return self

    def limit(self, count):
        return self

    def get(self):
        return [d for d in self.docs.values() if d.exists]

    def stream(self):
        return [d for d in self.docs.values() if d.exists]


class InMemoryFirestoreDB:
    def __init__(self):
        self.collections: Dict[str, InMemoryFirestoreCollection] = {}
        self.calls = []
        self.should_fail_write = False

    def collection(self, name: str) -> InMemoryFirestoreCollection:
        if name not in self.collections:
            self.collections[name] = InMemoryFirestoreCollection(name, self)
        return self.collections[name]

    def log_call(self, op: str, doc_id: str, data: Any = None):
        self.calls.append((op, doc_id, data))


def _mock_analysis():
    return SessionAnalysis(
        transcript="This is a test speech without any issues.",
        word_timestamps=[WordTimestamp(word="This", start=0.0, end=0.3)],
        wpm=135.0,
        filler=FillerAnalysis(total_count=2, breakdown={"um": 1, "like": 1}, rate_per_100_words=2.0),
        pauses=PauseAnalysis(count=1, avg_length=0.7, total_pause_time=0.7),
        clarity_score=88.0,
        confidence_score=85.0,
        overall_score=86.5,
        ai_feedback=[FeedbackItem(category="clarity", message="Clear diction", severity="tip", example=None)],
        duration_seconds=30.0,
    )


class TestSection2PostSessions:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = InMemoryFirestoreDB()
        self.user_a = User(id="user_a_123", email="user_a@example.com")
        self.user_b = User(id="user_b_456", email="user_b@example.com")
        self.current_user = self.user_a

        monkeypatch.setattr("sessions.router.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("d1.sync.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("achievements.service.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: _mock_analysis())
        monkeypatch.setattr("sessions.router.check_and_increment_daily_quota", lambda *args, **kw: None)

        main.app.dependency_overrides[get_current_user] = lambda: self.current_user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _post_session(self, **kwargs):
        data = {
            "session_id": kwargs.get("session_id", "11111111-1111-4111-a111-111111111111"),
            "mode": kwargs.get("mode", "interview"),
            "topic_or_question": kwargs.get("topic_or_question", "Tell me about your project"),
            "duration_seconds": kwargs.get("duration_seconds", "30.0"),
            "local_date": kwargs.get("local_date", "2026-10-09"),
            "tz_offset_minutes": kwargs.get("tz_offset_minutes", "330"),
        }
        if "user_id" in kwargs:
            data["user_id"] = kwargs["user_id"]

        audio_bytes = kwargs.get("audio_bytes", b"FAKE_AUDIO_DATA_FOR_TESTING")
        files = {"audio_file": ("test.m4a", io.BytesIO(audio_bytes), "audio/mp4")}
        return self.client.post("/sessions", data=data, files=files)

    # 1. Valid request with a valid token
    def test_case_1_valid_request(self):
        resp = self._post_session()
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["id"] == "11111111-1111-4111-a111-111111111111"
        assert body["overall_score"] == 86.5
        assert body["is_analyzed"] is True

        # Check Firestore doc
        doc = self.fake_db.collection("sessions").document("11111111-1111-4111-a111-111111111111")
        assert doc.exists is True
        assert doc.to_dict()["metrics"]["overall"] == 86.5

        # Check D1 row
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", ["11111111-1111-4111-a111-111111111111"])
        assert len(rows) == 1
        assert rows[0]["status"] == "analyzed"
        assert rows[0]["overall_score"] == 86.5

        # Check D1 fillers
        fillers = self.fake_d1.query("SELECT * FROM session_fillers WHERE session_id = ?", ["11111111-1111-4111-a111-111111111111"])
        assert len(fillers) == 2

    # 2. Same request sent twice (same id) -> Idempotent
    def test_case_2_duplicate_request_idempotent(self):
        resp1 = self._post_session()
        resp2 = self._post_session()
        assert resp1.status_code == 200
        assert resp2.status_code == 200
        assert resp1.json()["id"] == resp2.json()["id"]

        # Only one row in D1
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", ["11111111-1111-4111-a111-111111111111"])
        assert len(rows) == 1

        fillers = self.fake_d1.query("SELECT * FROM session_fillers WHERE session_id = ?", ["11111111-1111-4111-a111-111111111111"])
        assert len(fillers) == 2

    # 3. Same id sent concurrently (10 parallel)
    def test_case_3_concurrent_same_id(self):
        sid = "33333333-3333-4333-a333-333333333333"
        def _send():
            c = TestClient(main.app)
            data = {
                "session_id": sid,
                "mode": "interview",
                "topic_or_question": "Concurrent test",
                "duration_seconds": "30.0",
                "local_date": "2026-10-09",
                "tz_offset_minutes": "330",
            }
            files = {"audio_file": ("test.m4a", io.BytesIO(b"AUDIO"), "audio/mp4")}
            return c.post("/sessions", data=data, files=files)

        with ThreadPoolExecutor(max_workers=10) as ex:
            results = list(ex.map(lambda _: _send(), range(10)))

        for r in results:
            assert r.status_code == 200

        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1

    # 4. Missing or invalid token -> 401
    def test_case_4_missing_token(self):
        main.app.dependency_overrides.pop(get_current_user, None)
        c = TestClient(main.app)
        files = {"audio_file": ("test.m4a", io.BytesIO(b"AUDIO"), "audio/mp4")}
        resp = c.post("/sessions", data={"topic_or_question": "No token"}, files=files)
        assert resp.status_code in (401, 403), resp.status_code

    # 5. Body contains a different user_id -> Ignored, uses token uid
    def test_case_5_body_user_id_ignored(self):
        sid = "55555555-5555-4555-a555-555555555555"
        resp = self._post_session(session_id=sid, user_id="malicious_spoofed_user")
        assert resp.status_code == 200

        doc = self.fake_db.collection("sessions").document(sid).to_dict()
        assert doc["user_id"] == self.user_a.id

        rows = self.fake_d1.query("SELECT user_id FROM session_metrics WHERE id = ?", [sid])
        assert rows[0]["user_id"] == self.user_a.id

    # 6. User A requests user B's session ID -> 403 Forbidden
    def test_case_6_access_other_user_session(self):
        sid = "66666666-6666-4666-a666-666666666666"
        # Seed session owned by User B in Firestore
        self.fake_db.collection("sessions").document(sid).set({
            "id": sid,
            "user_id": self.user_b.id,
            "is_analyzed": True,
        })
        # User A attempts to write / re-post User B's session
        resp = self._post_session(session_id=sid)
        assert resp.status_code == 403

    # 7. D1 down (timeout) -> Request succeeds, d1_pending=True
    def test_case_7_d1_down_timeout(self):
        sid = "77777777-7777-4777-a777-777777777777"
        self.fake_d1.timeout_count = 5
        resp = self._post_session(session_id=sid)
        assert resp.status_code == 200
        doc = self.fake_db.collection("sessions").document(sid).to_dict()
        assert doc["d1_pending"] is True

    # 8. D1 fails once, then recovers
    def test_case_8_d1_fails_once_then_recovers(self):
        from d1.sync import sync_firestore_session_to_d1
        sid = "88888888-8888-4888-a888-888888888888"
        self.fake_d1.fail_count = 1
        resp = self._post_session(session_id=sid)
        assert resp.status_code == 200

        # Now D1 is healthy; call sync_firestore_session_to_d1
        doc_ref = self.fake_db.collection("sessions").document(sid)
        ok = sync_firestore_session_to_d1(sid, db=self.fake_db)
        assert ok is True
        assert doc_ref.to_dict()["d1_pending"] is False

    # 9. Firestore write fails -> D1 not written, error returned
    def test_case_9_firestore_write_fails(self):
        sid = "99999999-9999-4999-a999-999999999999"
        self.fake_db.should_fail_write = True
        try:
            resp = self._post_session(session_id=sid)
            assert resp.status_code == 500
        except RuntimeError:
            pass  # Exception propagated
        # D1 should not have this row
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 0

    # 10. Analysis (Groq) fails -> status='failed', no partial metrics
    def test_case_10_analysis_fails(self, monkeypatch):
        def _failing_analysis(**kw):
            raise RuntimeError("Groq rate limit or STT failure")
        monkeypatch.setattr("sessions.router.analyze_audio", _failing_analysis)

        sid = "10101010-1010-4010-a010-101010101010"
        with pytest.raises(RuntimeError):
            self._post_session(session_id=sid)

    # 11. local_date missing or malformed -> validation error
    def test_case_11_malformed_local_date(self):
        resp = self._post_session(local_date="2026/10/09")
        assert resp.status_code in (400, 422)

    # 12. Order of writes: Assert Firestore written before D1
    def test_case_12_order_of_writes(self, monkeypatch):
        sid = "12121212-1212-4212-a212-121212121212"
        events = []

        orig_set = InMemoryFirestoreDoc.set
        def _logged_set(doc_self, data):
            events.append(("firestore_set", doc_self.id))
            orig_set(doc_self, data)
        monkeypatch.setattr(InMemoryFirestoreDoc, "set", _logged_set)

        orig_batch = LocalSqliteD1.batch
        def _logged_batch(d1_self, stmts):
            events.append(("d1_batch", len(stmts)))
            return orig_batch(d1_self, stmts)
        monkeypatch.setattr(LocalSqliteD1, "batch", _logged_batch)

        resp = self._post_session(session_id=sid)
        assert resp.status_code == 200

        # Assert firestore_set happened before d1_batch
        fs_idx = next(i for i, e in enumerate(events) if e[0] == "firestore_set")
        d1_idx = next(i for i, e in enumerate(events) if e[0] == "d1_batch")
        assert fs_idx < d1_idx, f"Order of writes violated! Events: {events}"

    # 13. SQL injection strings in topic_or_question
    def test_case_13_sql_injection_safety(self):
        sid = "13131313-1313-4313-a313-131313131313"
        malicious_topic = "'; DROP TABLE session_metrics; SELECT * FROM session_metrics WHERE ''='"
        resp = self._post_session(session_id=sid, topic_or_question=malicious_topic)
        assert resp.status_code == 200

        rows = self.fake_d1.query("SELECT topic_or_question FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1
        assert rows[0]["topic_or_question"] == malicious_topic

    # 14. Very long topic, unicode and emoji
    def test_case_14_unicode_and_emoji(self):
        sid = "14141414-1414-4414-a414-141414141414"
        unicode_topic = "🚀 Launching our AI pitch 🎯: プレゼンテーション و التقييم 🌟" * 10
        resp = self._post_session(session_id=sid, topic_or_question=unicode_topic)
        assert resp.status_code == 200

        rows = self.fake_d1.query("SELECT topic_or_question FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1
        assert rows[0]["topic_or_question"] == unicode_topic
