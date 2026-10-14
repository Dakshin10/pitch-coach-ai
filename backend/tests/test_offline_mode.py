"""Feature 13: Offline Mode & Synchronization Resilience Backend Tests."""
import io
import json
import os
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import pytest
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from firestore import get_db
import main
from models import User
from sessions.pipeline import SessionAnalysis, FillerAnalysis, PauseAnalysis, FeedbackItem, WordTimestamp

D1_MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "d1", "migrations"))


class LocalSqliteD1:
    def __init__(self):
        self.lock = threading.Lock()
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON;")
        for mf in sorted([f for f in os.listdir(D1_MIGRATIONS_DIR) if f.endswith(".sql")]):
            with open(os.path.join(D1_MIGRATIONS_DIR, mf), "r", encoding="utf-8") as f:
                self.conn.executescript(f.read())

    @property
    def is_configured(self) -> bool:
        return True

    def query(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            rows = cursor.fetchall()
            return [dict(r) for r in rows]

    def execute(self, sql: str, params: Optional[List[Any]] = None) -> Dict[str, Any]:
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            self.conn.commit()
            return {"results": [], "changes": cursor.rowcount, "meta": {}}

    def batch(self, statements: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        with self.lock:
            cursor = self.conn.cursor()
            results = []
            for stmt in statements:
                if isinstance(stmt, tuple):
                    sql = stmt[0]
                    params = stmt[1] if len(stmt) > 1 else []
                elif isinstance(stmt, dict):
                    sql = stmt["sql"]
                    params = stmt.get("params", [])
                else:
                    raise ValueError(f"Invalid statement: {type(stmt)}")
                cursor.execute(sql, params)
                results.append({"results": [], "changes": cursor.rowcount})
            self.conn.commit()
            return results


class InMemoryFirestoreDoc:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]] = None):
        self.id = doc_id
        self._data = data.copy() if data else {}
        self.exists = data is not None

    def to_dict(self):
        return self._data.copy()

    def get(self):
        return self

    def set(self, data: Dict[str, Any]):
        self._data = data.copy()
        self.exists = True

    def update(self, data: Dict[str, Any]):
        self._data.update(data)


class InMemoryFirestoreCollection:
    def __init__(self, name: str):
        self.name = name
        self.docs: Dict[str, InMemoryFirestoreDoc] = {}

    def document(self, doc_id: str) -> InMemoryFirestoreDoc:
        if doc_id not in self.docs:
            self.docs[doc_id] = InMemoryFirestoreDoc(doc_id)
        return self.docs[doc_id]

    def where(self, *args, **kwargs):
        class _Query:
            def __init__(self, docs):
                self._docs = docs
            def stream(self):
                return [d for d in self._docs.values() if d.exists]
            def get(self):
                return self.stream()
            def limit(self, n):
                return self
            def order_by(self, *a, **k):
                return self
        return _Query(self.docs)

    def stream(self):
        return [d for d in self.docs.values() if d.exists]


class InMemoryFirestoreDB:
    def __init__(self):
        self.collections: Dict[str, InMemoryFirestoreCollection] = {}

    def collection(self, name: str) -> InMemoryFirestoreCollection:
        if name not in self.collections:
            self.collections[name] = InMemoryFirestoreCollection(name)
        return self.collections[name]


def make_dummy_analysis(duration: float = 30.0) -> SessionAnalysis:
    return SessionAnalysis(
        overall_score=85.0,
        clarity_score=82.0,
        confidence_score=88.0,
        structure_score=80.0,
        wpm=140.0,
        duration_seconds=duration,
        filler=FillerAnalysis(total_count=2, breakdown={"like": 1, "um": 1}, rate_per_100_words=2.0),
        pauses=PauseAnalysis(count=1, avg_length=1.2, total_pause_time=1.2),
        ai_feedback=[FeedbackItem(category="Pacing", message="Great cadence", severity="low")],
        transcript="This is a test speech from offline recording.",
        word_timestamps=[WordTimestamp(word="This", start=0.0, end=0.3)],
    )


class TestOfflineModeAndSync:
    @pytest.fixture(autouse=True)
    def setup_mocks(self, monkeypatch):
        self.fake_db = InMemoryFirestoreDB()
        self.fake_d1 = LocalSqliteD1()
        self.user_a = User(id="user_offline_123", email="offline@test.com")
        self.user_b = User(id="other_user_999", email="other@test.com")
        self.current_user = self.user_a

        monkeypatch.setattr("sessions.router.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("d1.sync.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("achievements.service.get_d1_client", lambda: self.fake_d1)
        monkeypatch.setattr("sessions.router.analyze_audio", lambda **kw: make_dummy_analysis())
        monkeypatch.setattr("sessions.router.check_and_increment_daily_quota", lambda *args, **kw: None)

        main.app.dependency_overrides[get_current_user] = lambda: self.current_user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _post_session(self, session_id: str, client: Optional[TestClient] = None):
        c = client or self.client
        audio_bytes = b"ID3\x03\x00\x00\x00\x00\x00#TSSE\x00\x00\x00\x0f\x00\x00\x03Lavf58.29.100\x00" + b"\x00" * 2000
        data = {
            "session_id": session_id,
            "mode": "interview",
            "topic_or_question": "Offline rehearsal question",
            "duration_seconds": "30.0",
            "local_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "tz_offset_minutes": "0",
        }
        files = {
            "audio_file": ("offline_take.m4a", io.BytesIO(audio_bytes), "audio/mp4"),
        }
        return c.post("/sessions", data=data, files=files, headers={"Authorization": "Bearer fake_token"})

    def test_offline_session_creation(self):
        """Offline client records and queues session, then posts with client UUID."""
        sid = str(uuid.uuid4())
        resp = self._post_session(sid)
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == sid
        assert data["is_analyzed"] is True
        assert data["overall_score"] == 85.0

        # Verify row in D1
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1
        assert rows[0]["user_id"] == "user_offline_123"

    def test_offline_duplicate_upload_is_idempotent(self):
        """Duplicate upload with same session ID must return identical analyzed response without duplicating rows."""
        sid = str(uuid.uuid4())
        resp1 = self._post_session(sid)
        assert resp1.status_code == 200

        # Duplicate re-transmission (e.g. outbox retry after network glitch)
        resp2 = self._post_session(sid)
        assert resp2.status_code == 200
        assert resp1.json()["id"] == resp2.json()["id"]
        assert resp2.json()["overall_score"] == 85.0

        # Verify D1 only has 1 record
        rows = self.fake_d1.query("SELECT * FROM session_metrics WHERE id = ?", [sid])
        assert len(rows) == 1

    def test_offline_inflight_session_is_idempotent(self):
        """Duplicate request while session is in stage='analyzing' returns in-progress session idempotently."""
        sid = str(uuid.uuid4())
        doc_ref = self.fake_db.collection("sessions").document(sid)
        doc_ref.set({
            "id": sid,
            "user_id": "user_offline_123",
            "mode": "interview",
            "topic_or_question": "Inflight test",
            "duration_seconds": 30.0,
            "stage": "analyzing",
            "is_analyzed": False,
            "created_at": datetime.now(timezone.utc),
        })

        resp = self._post_session(sid)
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == sid
        assert data["is_analyzed"] is False

    def test_offline_cross_user_isolation(self):
        """Submitting session_id owned by another user returns 403 Forbidden."""
        sid = str(uuid.uuid4())
        doc_ref = self.fake_db.collection("sessions").document(sid)
        doc_ref.set({
            "id": sid,
            "user_id": "other_user_999",
            "mode": "interview",
            "topic_or_question": "Other user's session",
            "is_analyzed": True,
            "created_at": datetime.now(timezone.utc),
        })

        resp = self._post_session(sid)
        assert resp.status_code == 403

    def test_offline_invalid_uuid_rejected(self):
        """Malformed non-UUID session_id returns 422 Unprocessable Entity."""
        resp = self._post_session("not-a-valid-uuid")
        assert resp.status_code == 422
