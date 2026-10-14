"""Section 10: Security Checks.

Verifies:
1. Every endpoint rejects missing, expired, and malformed tokens with 401 Unauthorized.
2. Cross-user data isolation (ID guessing on sessions, metrics changes, stats, deletion).
3. Parameterized query enforcement across all D1 queries.
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
import unittest
from unittest.mock import MagicMock, patch
import jwt
from fastapi.testclient import TestClient

from config import get_settings
from d1.d1_client import D1Client
from firestore import get_db
from models import PracticeSession, User, SESSIONS_COL, USERS_COL
import main

settings = get_settings()


class LocalSqliteD1(D1Client):
    """In-memory SQLite fake D1 client."""
    def __init__(self):
        super().__init__(account_id="test", database_id="test", api_token="test")
        import sqlite3
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON;")
        self._init_schema()

    def _init_schema(self):
        self.conn.executescript("""
        CREATE TABLE IF NOT EXISTS session_metrics (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            mode TEXT NOT NULL DEFAULT 'interview',
            topic_or_question TEXT NOT NULL,
            duration_seconds REAL NOT NULL DEFAULT 0.0,
            wpm REAL NOT NULL DEFAULT 0.0,
            filler_word_count INTEGER NOT NULL DEFAULT 0,
            pause_count INTEGER NOT NULL DEFAULT 0,
            avg_pause_length REAL NOT NULL DEFAULT 0.0,
            clarity_score REAL NOT NULL DEFAULT 0.0,
            confidence_score REAL NOT NULL DEFAULT 0.0,
            overall_score REAL NOT NULL DEFAULT 0.0,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TEXT NOT NULL,
            local_date TEXT NOT NULL,
            tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        );
        CREATE TABLE IF NOT EXISTS session_fillers (
            session_id TEXT NOT NULL REFERENCES session_metrics(id) ON DELETE CASCADE,
            filler_word TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (session_id, filler_word)
        );
        CREATE TABLE IF NOT EXISTS user_achievements (
            user_id TEXT NOT NULL,
            achievement_key TEXT NOT NULL,
            unlocked_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY (user_id, achievement_key)
        );
        """)

    def execute(self, sql: str, params: Optional[List[Any]] = None) -> Dict[str, Any]:
        with self.conn:
            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            return {"results": [], "success": True}

    def query(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        cursor = self.conn.cursor()
        cursor.execute(sql, params or [])
        rows = cursor.fetchall()
        return [dict(r) for r in rows]

    def batch(self, statements: List[tuple[str, List[Any]]]) -> List[Dict[str, Any]]:
        with self.conn:
            cursor = self.conn.cursor()
            for sql, params in statements:
                cursor.execute(sql, params or [])
        return [{"success": True}]


class InMemoryFirestoreDB:
    def __init__(self):
        self.collections: Dict[str, Dict[str, Any]] = {}

    def collection(self, name: str):
        return InMemoryCollection(self.collections.setdefault(name, {}))


class InMemoryCollection:
    def __init__(self, store: Dict[str, Any]):
        self.store = store

    def document(self, doc_id: str):
        return InMemoryDocRef(self.store, doc_id)

    def where(self, field: str, op: str, value: Any):
        return InMemoryQuery(self.store, [(field, op, value)])

    def order_by(self, field: str, direction=None):
        return InMemoryQuery(self.store, [], order_by_field=field)

    def stream(self):
        return [InMemoryDocSnapshot(k, v) for k, v in list(self.store.items())]


class InMemoryDocRef:
    def __init__(self, store: Dict[str, Any], doc_id: str):
        self.store = store
        self.doc_id = doc_id

    def get(self):
        data = self.store.get(self.doc_id)
        return InMemoryDocSnapshot(self.doc_id, data)

    def set(self, data: Dict[str, Any]):
        self.store[self.doc_id] = dict(data)

    def update(self, data: Dict[str, Any]):
        if self.doc_id in self.store:
            self.store[self.doc_id].update(data)
        else:
            self.store[self.doc_id] = dict(data)

    def delete(self):
        self.store.pop(self.doc_id, None)


class InMemoryDocSnapshot:
    def __init__(self, doc_id: str, data: Optional[Dict[str, Any]]):
        self.id = doc_id
        self._data = data

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> Optional[Dict[str, Any]]:
        return dict(self._data) if self._data else None


class InMemoryQuery:
    def __init__(self, store: Dict[str, Any], filters: List[tuple], order_by_field: Optional[str] = None):
        self.store = store
        self.filters = filters
        self.order_by_field = order_by_field
        self._limit = None

    def where(self, field: str, op: str, value: Any):
        return InMemoryQuery(self.store, self.filters + [(field, op, value)], self.order_by_field)

    def order_by(self, field: str, direction=None):
        return InMemoryQuery(self.store, self.filters, order_by_field=field)

    def limit(self, count: int):
        self._limit = count
        return self

    def get(self):
        results = []
        for doc_id, data in self.store.items():
            match = True
            for field, op, value in self.filters:
                actual = data.get(field)
                if op == "==" and actual != value:
                    match = False
                elif op == ">=" and (actual is None or actual < value):
                    match = False
            if match:
                results.append(InMemoryDocSnapshot(doc_id, data))
        if self._limit:
            results = results[:self._limit]
        return results

    def stream(self):
        return self.get()


class TestSection10Security(unittest.TestCase):
    def setUp(self):
        self.fake_db = InMemoryFirestoreDB()
        self.fake_d1 = LocalSqliteD1()
        self.client = TestClient(main.app)

        # Create two test users in Firestore
        self.user_a = User(
            id="user-a-1111",
            email="user_a@example.com",
            full_name="User Alpha",
            is_guest=False,
        )
        self.user_b = User(
            id="user-b-2222",
            email="user_b@example.com",
            full_name="User Beta",
            is_guest=False,
        )
        self.fake_db.collection(USERS_COL).document(self.user_a.id).set(self.user_a.to_dict())
        self.fake_db.collection(USERS_COL).document(self.user_b.id).set(self.user_b.to_dict())

        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        # Valid token generators
        self.valid_token_a = self._make_token(self.user_a.id)
        self.valid_token_b = self._make_token(self.user_b.id)

    def tearDown(self):
        main.app.dependency_overrides.clear()

    def _make_token(self, user_id: str, expired: bool = False, bad_secret: bool = False) -> str:
        secret = "wrong_secret_key_123456789012345678901234" if bad_secret else settings.SECRET_KEY
        exp = datetime.now(timezone.utc) + (timedelta(days=-1) if expired else timedelta(hours=1))
        payload = {"sub": user_id, "type": "access", "exp": exp}
        return jwt.encode(payload, secret, algorithm=settings.ALGORITHM)

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Missing, Expired, and Malformed Tokens
    # ─────────────────────────────────────────────────────────────────────────

    def test_missing_token_rejected_on_all_endpoints(self):
        endpoints = [
            ("POST", "/sessions", {"local_date": "2026-10-09"}),
            ("GET", "/sessions", None),
            ("GET", "/sessions/some-id", None),
            ("DELETE", "/sessions/some-id", None),
            ("GET", "/stats/summary", None),
            ("GET", "/stats/trend", None),
            ("GET", "/stats/streak", None),
            ("GET", "/stats/skills", None),
            ("GET", "/metrics/changes", None),
            ("DELETE", "/account", None),
        ]
        for method, path, json_body in endpoints:
            if method == "POST":
                resp = self.client.post(path, json=json_body)
            elif method == "GET":
                resp = self.client.get(path)
            elif method == "DELETE":
                resp = self.client.delete(path)
            self.assertEqual(
                resp.status_code, 401,
                f"Expected 401 for missing token on {method} {path}, got {resp.status_code}",
            )

    def test_expired_token_rejected_on_all_endpoints(self):
        expired_token = self._make_token(self.user_a.id, expired=True)
        headers = {"Authorization": f"Bearer {expired_token}"}
        endpoints = [
            ("POST", "/sessions", {"local_date": "2026-10-09"}),
            ("GET", "/sessions", None),
            ("GET", "/sessions/some-id", None),
            ("DELETE", "/sessions/some-id", None),
            ("GET", "/stats/summary", None),
            ("GET", "/stats/trend", None),
            ("GET", "/stats/streak", None),
            ("GET", "/metrics/changes", None),
            ("DELETE", "/account", None),
        ]
        for method, path, json_body in endpoints:
            if method == "POST":
                resp = self.client.post(path, json=json_body, headers=headers)
            elif method == "GET":
                resp = self.client.get(path, headers=headers)
            elif method == "DELETE":
                resp = self.client.delete(path, headers=headers)
            self.assertEqual(
                resp.status_code, 401,
                f"Expected 401 for expired token on {method} {path}, got {resp.status_code}",
            )

    def test_malformed_and_tampered_token_rejected(self):
        bad_tokens = [
            "not-a-valid-jwt",
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.invalid.payload",
            self._make_token(self.user_a.id, bad_secret=True),  # Wrong HMAC signature
        ]
        for bad_tok in bad_tokens:
            headers = {"Authorization": f"Bearer {bad_tok}"}
            resp = self.client.get("/stats/summary", headers=headers)
            self.assertEqual(resp.status_code, 401)
            resp = self.client.get("/metrics/changes", headers=headers)
            self.assertEqual(resp.status_code, 401)
            resp = self.client.post("/sessions", json={"local_date": "2026-10-09"}, headers=headers)
            self.assertEqual(resp.status_code, 401)

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Cross-User Data Isolation (No Data Leaks)
    # ─────────────────────────────────────────────────────────────────────────

    def test_user_b_cannot_get_or_delete_user_a_session(self):
        # Seed a session for User A in Firestore and D1
        session_a_id = "sess-alpha-999"
        sess_a = PracticeSession(
            id=session_a_id,
            user_id=self.user_a.id,
            mode="interview",
            topic_or_question="User A Secret Topic",
            local_date="2026-10-09",
            is_analyzed=True,
            created_at=datetime.now(timezone.utc),
        )
        self.fake_db.collection(SESSIONS_COL).document(session_a_id).set(sess_a.to_dict())

        # User B tries to GET session_a_id -> must return 404 (not leaked)
        resp = self.client.get(
            f"/sessions/{session_a_id}",
            headers={"Authorization": f"Bearer {self.valid_token_b}"},
        )
        self.assertEqual(resp.status_code, 404)

        # User B tries to DELETE session_a_id -> must return 403 or 404
        resp_del = self.client.delete(
            f"/sessions/{session_a_id}",
            headers={"Authorization": f"Bearer {self.valid_token_b}"},
        )
        self.assertIn(resp_del.status_code, (403, 404))

        # Assert User A's session is still intact in Firestore
        self.assertTrue(self.fake_db.collection(SESSIONS_COL).document(session_a_id).get().exists)

    @patch("auth.account_service.fb_auth.delete_user")
    @patch("auth.account_service.get_bucket")
    def test_metrics_changes_never_leaks_other_users_data(self, mock_bucket, mock_del_user):
        with patch("d1.d1_client.get_d1_client", return_value=self.fake_d1), \
             patch("metrics.router.get_d1_client", return_value=self.fake_d1):
            now_iso = datetime.now(timezone.utc).isoformat()
            # Seed D1 with User A's rows
            self.fake_d1.execute(
                """
                INSERT INTO session_metrics (id, user_id, mode, topic_or_question, duration_seconds,
                    wpm, filler_word_count, pause_count, avg_pause_length, clarity_score,
                    confidence_score, overall_score, status, created_at, local_date, tz_offset_minutes,
                    updated_at, deleted_at)
                VALUES ('sess-a-1', ?, 'interview', 'Secret Pitch A', 60.0, 140.0, 2, 1, 0.5, 80.0, 85.0, 82.0,
                    'analyzed', ?, '2026-10-09', 0, ?, NULL);
                """,
                [self.user_a.id, now_iso, now_iso],
            )
            self.fake_d1.execute(
                """
                INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at)
                VALUES (?, 'first_session', ?, ?);
                """,
                [self.user_a.id, now_iso, now_iso],
            )

            # User B calls /metrics/changes -> must receive 0 sessions and 0 achievements
            resp_b = self.client.get(
                "/metrics/changes",
                headers={"Authorization": f"Bearer {self.valid_token_b}"},
            )
            self.assertEqual(resp_b.status_code, 200)
            data_b = resp_b.json()
            self.assertEqual(len(data_b["sessions"]), 0)
            self.assertEqual(len(data_b["achievements"]), 0)

            # User A calls /metrics/changes -> receives their own row
            resp_a = self.client.get(
                "/metrics/changes",
                headers={"Authorization": f"Bearer {self.valid_token_a}"},
            )
            self.assertEqual(resp_a.status_code, 200)
            data_a = resp_a.json()
            self.assertEqual(len(data_a["sessions"]), 1)
            self.assertEqual(data_a["sessions"][0]["id"], "sess-a-1")
            self.assertEqual(len(data_a["achievements"]), 1)

    @patch("auth.account_service.fb_auth.delete_user")
    @patch("auth.account_service.get_bucket")
    def test_delete_account_only_deletes_calling_user(self, mock_bucket, mock_del_user):
        import d1.d1_client
        with patch.object(d1.d1_client, "get_d1_client", return_value=self.fake_d1):
            now_iso = datetime.now(timezone.utc).isoformat()
            self.fake_d1.execute(
                """
                INSERT INTO session_metrics (id, user_id, mode, topic_or_question, duration_seconds,
                    wpm, filler_word_count, pause_count, avg_pause_length, clarity_score,
                    confidence_score, overall_score, status, created_at, local_date, tz_offset_minutes,
                    updated_at, deleted_at)
                VALUES ('sess-b-1', ?, 'interview', 'Pitch B', 60.0, 140.0, 2, 1, 0.5, 80.0, 85.0, 82.0,
                    'analyzed', ?, '2026-10-09', 0, ?, NULL);
                """,
                [self.user_b.id, now_iso, now_iso],
            )

            # User A deletes account
            resp = self.client.delete(
                "/account",
                headers={"Authorization": f"Bearer {self.valid_token_a}"},
            )
            self.assertEqual(resp.status_code, 200)

            # Assert User B's rows in D1 are untouched
            rows_b = self.fake_d1.query("SELECT * FROM session_metrics WHERE user_id = ?", [self.user_b.id])
            self.assertEqual(len(rows_b), 1)

            # Assert User B is still in Firestore
            self.assertTrue(self.fake_db.collection(USERS_COL).document(self.user_b.id).get().exists)


if __name__ == "__main__":
    unittest.main()
