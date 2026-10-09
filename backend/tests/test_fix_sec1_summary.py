"""Section 1 Fix Tests: /stats/summary drops metrics (DEFECT-02).

Verifies that GET /stats/summary returns the full set of metrics:
- total_sessions
- avg_score
- avg_wpm
- avg_clarity
- avg_confidence
- total_duration
- streak_days
- filler_reduction_pct

Covering:
1. Normal user with known fixtures (exact numbers asserted).
2. Empty user (zeros or nulls in documented shape, no divide-by-zero).
3. User with failed, pending, and soft-deleted rows (asserted to be excluded).
4. D1-down fallback path (asserted that response shape is identical, with uncomputable fields as null, never missing).
"""
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import unittest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from d1.d1_client import D1Client, D1ConnectionError
from firestore import get_db
from models import User
import main


class LocalSqliteD1(D1Client):
    """In-memory SQLite fake D1 client with failure injection."""
    def __init__(self):
        super().__init__(account_id="test", database_id="test", api_token="test")
        import sqlite3
        self.conn = sqlite3.connect(":memory:", check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON;")
        self._init_schema()
        self.is_down = False

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
        if self.is_down:
            raise D1ConnectionError("Simulated D1 outage")
        with self.conn:
            cursor = self.conn.cursor()
            cursor.execute(sql, params or [])
            return {"results": [], "success": True}

    def query(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        if self.is_down:
            raise D1ConnectionError("Simulated D1 outage")
        cursor = self.conn.cursor()
        cursor.execute(sql, params or [])
        rows = cursor.fetchall()
        return [dict(r) for r in rows]


class FakeFirestoreDB:
    def __init__(self):
        self._count = 0
        self._avg_conf = 0.0
        self._docs = []

    def collection(self, name: str):
        return self

    def where(self, field: str, op: str, value: Any):
        return self

    def count(self, alias: str = "count"):
        self._count_alias = alias
        return self

    def avg(self, field: str, alias: str = "avg_conf"):
        self._avg_alias = alias
        return self

    def get(self):
        item_count = MagicMock()
        item_count.alias = "count"
        item_count.value = self._count
        item_conf = MagicMock()
        item_conf.alias = "avg_conf"
        item_conf.value = self._avg_conf
        return [[item_count, item_conf]]

    def order_by(self, field: str, direction=None):
        return self

    def limit(self, count: int):
        mock_limit = MagicMock()
        mock_limit.get.return_value = self._docs
        return mock_limit


class TestFixSection1Summary(unittest.TestCase):
    def setUp(self):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = FakeFirestoreDB()
        self.client = TestClient(main.app)

        self.user = User(
            id="user_summary_fix",
            email="summary_fix@example.com",
            full_name="Summary Tester",
            is_guest=False,
        )
        self.current_user = self.user

        main.app.dependency_overrides[get_current_user] = lambda: self.current_user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

    def tearDown(self):
        main.app.dependency_overrides.clear()

    def _seed_session(
        self,
        sid: str,
        user_id: str,
        duration: float,
        wpm: float,
        clarity: float,
        confidence: float,
        overall: float,
        status: str = "analyzed",
        deleted_at: Optional[str] = None,
        local_date: str = "2026-10-09",
        fillers: int = 2,
    ):
        now_iso = datetime.now(timezone.utc).isoformat()
        self.fake_d1.execute(
            """
            INSERT INTO session_metrics (
                id, user_id, mode, topic_or_question, duration_seconds,
                wpm, filler_word_count, pause_count, avg_pause_length,
                clarity_score, confidence_score, overall_score,
                status, created_at, local_date, tz_offset_minutes,
                updated_at, deleted_at
            ) VALUES (?, ?, 'interview', 'Summary Test Topic', ?, ?, ?, 1, 0.5, ?, ?, ?, ?, ?, ?, 330, ?, ?);
            """,
            [
                sid, user_id, duration, wpm, fillers,
                clarity, confidence, overall,
                status, now_iso, local_date, now_iso, deleted_at,
            ],
        )

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Normal User Endpoint Test
    # ─────────────────────────────────────────────────────────────────────────

    def test_stats_summary_normal_user_includes_all_metrics(self):
        """DEFECT-02: GET /stats/summary must return avg_score, avg_wpm, avg_clarity, avg_confidence, and total_duration."""
        import stats.router
        with patch.object(stats.router, "get_d1_client", return_value=self.fake_d1):
            # Seed 2 valid analyzed sessions:
            # Session 1: duration=60, wpm=140, clarity=90, confidence=80, overall=85
            # Session 2: duration=40, wpm=120, clarity=80, confidence=70, overall=75
            # Expected averages:
            # total_sessions = 2
            # avg_score = (85 + 75) / 2 = 80.0
            # avg_wpm = (140 + 120) / 2 = 130.0
            # avg_clarity = (90 + 80) / 2 = 85.0
            # avg_confidence = (80 + 70) / 2 = 75.0
            # total_duration = 60 + 40 = 100.0
            self._seed_session("s1", self.user.id, duration=60.0, wpm=140.0, clarity=90.0, confidence=80.0, overall=85.0)
            self._seed_session("s2", self.user.id, duration=40.0, wpm=120.0, clarity=80.0, confidence=70.0, overall=75.0)

            resp = self.client.get("/stats/summary")
            self.assertEqual(resp.status_code, 200)
            data = resp.json()

            # Required fields asserted
            self.assertIn("total_sessions", data)
            self.assertIn("avg_score", data, "DEFECT-02: avg_score is missing from /stats/summary response JSON")
            self.assertIn("avg_wpm", data, "DEFECT-02: avg_wpm is missing from /stats/summary response JSON")
            self.assertIn("avg_clarity", data, "DEFECT-02: avg_clarity is missing from /stats/summary response JSON")
            self.assertIn("avg_confidence", data)
            self.assertIn("total_duration", data, "DEFECT-02: total_duration is missing from /stats/summary response JSON")
            self.assertIn("streak_days", data)
            self.assertIn("filler_reduction_pct", data)

            # Exact numbers asserted
            self.assertEqual(data["total_sessions"], 2)
            self.assertEqual(data["avg_score"], 80.0)
            self.assertEqual(data["avg_wpm"], 130.0)
            self.assertEqual(data["avg_clarity"], 85.0)
            self.assertEqual(data["avg_confidence"], 75.0)
            self.assertEqual(data["total_duration"], 100.0)

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Empty User Test
    # ─────────────────────────────────────────────────────────────────────────

    def test_stats_summary_empty_user(self):
        """Empty user returns documented shape with zeros/nulls and no divide-by-zero error."""
        import stats.router
        with patch.object(stats.router, "get_d1_client", return_value=self.fake_d1):
            empty_user = User(id="user_empty", email="empty@example.com")
            self.current_user = empty_user

            resp = self.client.get("/stats/summary")
            self.assertEqual(resp.status_code, 200)
            data = resp.json()

            self.assertEqual(data["total_sessions"], 0)
            self.assertEqual(data["avg_confidence"], 0.0)
            self.assertEqual(data["streak_days"], 0)
            self.assertEqual(data["filler_reduction_pct"], 0.0)

            # Fields must exist and be 0.0 or null
            self.assertIn("avg_score", data)
            self.assertIn("avg_wpm", data)
            self.assertIn("avg_clarity", data)
            self.assertIn("total_duration", data)
            self.assertIn(data["avg_score"], (0.0, None))
            self.assertIn(data["avg_wpm"], (0.0, None))
            self.assertIn(data["avg_clarity"], (0.0, None))
            self.assertIn(data["total_duration"], (0.0, None))

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Exclude Failed, Pending, Soft-deleted Rows
    # ─────────────────────────────────────────────────────────────────────────

    def test_stats_summary_excludes_failed_pending_and_deleted(self):
        """Failed, pending, and soft-deleted rows must not be included in averages or totals."""
        import stats.router
        with patch.object(stats.router, "get_d1_client", return_value=self.fake_d1):
            # 1 valid session:
            self._seed_session("valid_1", self.user.id, duration=50.0, wpm=150.0, clarity=90.0, confidence=90.0, overall=90.0, status="analyzed")

            # 1 failed session (should be ignored):
            self._seed_session("failed_1", self.user.id, duration=10.0, wpm=50.0, clarity=20.0, confidence=20.0, overall=20.0, status="failed")

            # 1 pending session (should be ignored):
            self._seed_session("pending_1", self.user.id, duration=20.0, wpm=60.0, clarity=30.0, confidence=30.0, overall=30.0, status="pending")

            # 1 soft-deleted session (should be ignored):
            now_iso = datetime.now(timezone.utc).isoformat()
            self._seed_session("deleted_1", self.user.id, duration=30.0, wpm=70.0, clarity=40.0, confidence=40.0, overall=40.0, status="analyzed", deleted_at=now_iso)

            resp = self.client.get("/stats/summary")
            self.assertEqual(resp.status_code, 200)
            data = resp.json()

            self.assertEqual(data["total_sessions"], 1)
            self.assertEqual(data["avg_score"], 90.0)
            self.assertEqual(data["avg_wpm"], 150.0)
            self.assertEqual(data["avg_clarity"], 90.0)
            self.assertEqual(data["avg_confidence"], 90.0)
            self.assertEqual(data["total_duration"], 50.0)

    # ─────────────────────────────────────────────────────────────────────────
    # 4. D1-Down Fallback Test
    # ─────────────────────────────────────────────────────────────────────────

    def test_stats_summary_d1_down_fallback_response_shape(self):
        """When D1 is unreachable, fallback response shape must be identical (uncomputable fields as null, never missing)."""
        import stats.router
        self.fake_d1.is_down = True
        self.fake_db._count = 3
        self.fake_db._avg_conf = 82.5

        with patch.object(stats.router, "get_d1_client", return_value=self.fake_d1):
            resp = self.client.get("/stats/summary")
            self.assertEqual(resp.status_code, 200)
            data = resp.json()

            # All keys must be present in the JSON response
            for key in ["total_sessions", "avg_confidence", "streak_days", "filler_reduction_pct",
                        "avg_score", "avg_wpm", "avg_clarity", "total_duration"]:
                self.assertIn(key, data, f"Key {key} must be present in fallback response")

            self.assertEqual(data["total_sessions"], 3)
            self.assertEqual(data["avg_confidence"], 82.5)

            # Fallback cannot compute SQL aggregates, so they must be explicitly null
            self.assertIsNone(data["avg_score"])
            self.assertIsNone(data["avg_wpm"])
            self.assertIsNone(data["avg_clarity"])
            self.assertIsNone(data["total_duration"])


if __name__ == "__main__":
    unittest.main()
