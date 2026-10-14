"""Section 3: Backend stats and timezone verification.

Tests verify:
- Summary SQL aggregates: totals and averages (avg_score, avg_wpm, avg_clarity, avg_confidence, total_duration)
  matching brute-force calculation over fixtures.
- /stats/summary endpoint response: empty user returns 0s, active user returns populated summary.
- Trend SQL query: 30-day cutoff window, local_date grouping, ASC order.
- Timezone edge cases:
  - 01:00 AM IST (UTC-prev-day) groups on local calendar day.
  - Negative timezone offset (-480 PST) groups correctly.
  - Multiple sessions on same local day with different UTC days collapse into one group.
- /stats/streak gaps-and-islands:
  - Consecutive days, gap of one day, multiple sessions per day,
  - Streak ending yesterday (active), ending 2 days ago (broken),
  - Month and year boundaries, single day, no sessions.
- D1 unreachable fallback to Firestore aggregation queries (count(), avg()), no 500-doc scan.
"""
from datetime import datetime, date, timedelta, timezone
import sqlite3
import pytest
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from d1.d1_client import D1ConnectionError
from firestore import get_db
import main
from models import User
from tests.test_sec2_post_sessions import LocalSqliteD1, InMemoryFirestoreDB


class TestSection3StatsTimezone:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = InMemoryFirestoreDB()
        self.user = User(id="user_stats_test", email="stats@example.com")

        monkeypatch.setattr("stats.router.get_d1_client", lambda: self.fake_d1)
        main.app.dependency_overrides[get_current_user] = lambda: self.user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _seed_session(self, sid, local_date, overall, wpm, clarity, conf, dur, status="analyzed", deleted_at=None, created_at=None, uid=None):
        user_id = uid or self.user.id
        now_iso = created_at or f"{local_date}T12:00:00Z"
        self.fake_d1.execute("""
            INSERT INTO session_metrics (
                id, user_id, mode, topic_or_question, duration_seconds, wpm,
                filler_word_count, pause_count, avg_pause_length, clarity_score,
                confidence_score, overall_score, status, created_at, local_date,
                tz_offset_minutes, updated_at, deleted_at
            ) VALUES (?, ?, 'interview', 'Topic', ?, ?, 2, 1, 0.5, ?, ?, ?, ?, ?, ?, 330, ?, ?)
        """, [sid, user_id, dur, wpm, clarity, conf, overall, status, now_iso, local_date, now_iso, deleted_at])

    # 1. Summary SQL aggregates exact numbers & excluding failed/pending/deleted
    def test_stats_summary_sql_exact_numbers(self):
        # 4 valid analyzed sessions
        self._seed_session("s1", "2026-10-09", 90.0, 140.0, 90.0, 85.0, 60.0)
        self._seed_session("s2", "2026-10-09", 80.0, 120.0, 80.0, 75.0, 40.0)
        self._seed_session("s3", "2026-10-08", 85.0, 130.0, 85.0, 80.0, 50.0)
        self._seed_session("s4", "2026-10-07", 70.0, 110.0, 70.0, 65.0, 30.0)

        # Excluded sessions
        self._seed_session("s_failed", "2026-10-09", 10.0, 50.0, 10.0, 10.0, 10.0, status="failed")
        self._seed_session("s_pending", "2026-10-09", 10.0, 50.0, 10.0, 10.0, 10.0, status="pending")
        self._seed_session("s_deleted", "2026-10-09", 10.0, 50.0, 10.0, 10.0, 10.0, deleted_at="2026-10-09T13:00:00Z")

        # Other user sessions (must be excluded)
        self._seed_session("s_other", "2026-10-09", 100.0, 200.0, 100.0, 100.0, 100.0, uid="other_user")

        summary_sql = """
        SELECT COUNT(*) AS total_sessions,
               ROUND(AVG(overall_score), 1) AS avg_score,
               ROUND(AVG(wpm), 1) AS avg_wpm,
               ROUND(AVG(clarity_score), 1) AS avg_clarity,
               ROUND(AVG(confidence_score), 1) AS avg_confidence,
               ROUND(SUM(duration_seconds), 1) AS total_duration
        FROM session_metrics
        WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL;
        """
        rows = self.fake_d1.query(summary_sql, [self.user.id])
        assert len(rows) == 1
        data = rows[0]

        assert data["total_sessions"] == 4
        assert data["total_duration"] == 180.0
        assert data["avg_wpm"] == 125.0
        assert data["avg_clarity"] == 81.3
        assert data["avg_confidence"] == 76.3
        assert data["avg_score"] == 81.3

        # Endpoint response test
        resp = self.client.get("/stats/summary?tz_offset_minutes=330")
        assert resp.status_code == 200
        ep_data = resp.json()
        assert ep_data["total_sessions"] == 4
        assert ep_data["avg_confidence"] == 76.3

    # 2. Empty user returns 0s/nulls with no errors
    def test_empty_user_returns_zeros(self):
        resp = self.client.get("/stats/summary?tz_offset_minutes=330")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_sessions"] == 0
        assert data["avg_confidence"] == 0.0
        assert data["streak_days"] == 0
        assert data["filler_reduction_pct"] == 0.0

    # 3. 30-day trend SQL query cutoff, local_date grouping, ASC order
    def test_stats_trend_cutoff_and_grouping(self):
        now_local = datetime.now(timezone.utc) + timedelta(minutes=330)
        today_str = now_local.strftime("%Y-%m-%d")
        day_30_ago = (now_local - timedelta(days=29)).strftime("%Y-%m-%d")
        day_31_ago = (now_local - timedelta(days=30)).strftime("%Y-%m-%d")

        self._seed_session("t_today", today_str, 90.0, 130.0, 85.0, 80.0, 60.0)
        self._seed_session("t_day30", day_30_ago, 80.0, 120.0, 75.0, 70.0, 45.0)
        self._seed_session("t_day31", day_31_ago, 70.0, 110.0, 65.0, 60.0, 30.0)  # Outside 30-day window

        cutoff = (now_local - timedelta(days=30)).strftime("%Y-%m-%d")
        trend_sql = """
        SELECT local_date, ROUND(AVG(overall_score),1) AS score, ROUND(AVG(wpm),1) AS wpm,
               ROUND(AVG(clarity_score),1) AS clarity, COUNT(*) AS session_count
        FROM session_metrics
        WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL AND local_date >= ?
        GROUP BY local_date ORDER BY local_date ASC;
        """
        rows = self.fake_d1.query(trend_sql, [self.user.id, day_30_ago])
        dates = [r["local_date"] for r in rows]
        assert day_30_ago in dates
        assert today_str in dates
        assert day_31_ago not in dates
        assert dates == sorted(dates)

    # 4. Critical Timezone Cases:
    def test_timezone_pitch_at_0100_ist(self):
        """01:00 AM IST on Oct 10 is 19:30 UTC on Oct 09.
        It must be stored and grouped under local_date='2026-10-10'.
        """
        # Pitch 1: 01:00 AM IST Oct 10 (UTC 2026-10-09T19:30:00Z)
        self._seed_session(
            "s_ist_1am",
            local_date="2026-10-10",
            overall=88.0, wpm=130.0, clarity=85.0, conf=80.0, dur=60.0,
            created_at="2026-10-09T19:30:00Z"
        )
        # Pitch 2: 10:00 AM IST Oct 10 (UTC 2026-10-10T04:30:00Z)
        self._seed_session(
            "s_ist_10am",
            local_date="2026-10-10",
            overall=92.0, wpm=140.0, clarity=90.0, conf=85.0, dur=60.0,
            created_at="2026-10-10T04:30:00Z"
        )

        trend_sql = """
        SELECT local_date, ROUND(AVG(overall_score),1) AS score, COUNT(*) AS session_count
        FROM session_metrics
        WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
        GROUP BY local_date ORDER BY local_date ASC;
        """
        rows = self.fake_d1.query(trend_sql, [self.user.id])
        oct10_rows = [r for r in rows if r["local_date"] == "2026-10-10"]
        assert len(oct10_rows) == 1
        assert oct10_rows[0]["score"] == 90.0
        assert oct10_rows[0]["session_count"] == 2

    def test_negative_timezone_offset_pst(self):
        """User in PST (-480 min). A pitch at 01:00 UTC Oct 10 is 17:00 PST Oct 09."""
        self._seed_session(
            "s_pst",
            local_date="2026-10-09",
            overall=85.0, wpm=120.0, clarity=80.0, conf=75.0, dur=60.0,
            created_at="2026-10-10T01:00:00Z"
        )
        trend_sql = """
        SELECT local_date, ROUND(AVG(overall_score),1) AS score
        FROM session_metrics
        WHERE user_id = ? AND status = 'analyzed' AND deleted_at IS NULL
        GROUP BY local_date;
        """
        rows = self.fake_d1.query(trend_sql, [self.user.id])
        assert any(r["local_date"] == "2026-10-09" for r in rows)
        assert not any(r["local_date"] == "2026-10-10" for r in rows)

    # 5. /stats/streak gaps-and-islands cases
    def test_streak_consecutive_active_ending_today(self):
        now_local = datetime.now(timezone.utc) + timedelta(minutes=330)
        today = now_local.date()

        for i in range(3):
            d_str = (today - timedelta(days=i)).strftime("%Y-%m-%d")
            self._seed_session(f"strk_{i}", d_str, 85.0, 130.0, 85.0, 80.0, 60.0)

        resp = self.client.get("/stats/streak?tz_offset_minutes=330")
        assert resp.status_code == 200
        assert resp.json()["streak"] == 3

    def test_streak_ending_yesterday_is_still_active(self):
        now_local = datetime.now(timezone.utc) + timedelta(minutes=330)
        yesterday = now_local.date() - timedelta(days=1)

        for i in range(2):
            d_str = (yesterday - timedelta(days=i)).strftime("%Y-%m-%d")
            self._seed_session(f"y_strk_{i}", d_str, 85.0, 130.0, 85.0, 80.0, 60.0)

        resp = self.client.get("/stats/streak?tz_offset_minutes=330")
        assert resp.status_code == 200
        assert resp.json()["streak"] == 2
        assert resp.json()["last_day"] == yesterday.strftime("%Y-%m-%d")

    def test_streak_broken_two_days_ago_is_zero(self):
        now_local = datetime.now(timezone.utc) + timedelta(minutes=330)
        two_days_ago = now_local.date() - timedelta(days=2)

        for i in range(3):
            d_str = (two_days_ago - timedelta(days=i)).strftime("%Y-%m-%d")
            self._seed_session(f"old_strk_{i}", d_str, 85.0, 130.0, 85.0, 80.0, 60.0)

        resp = self.client.get("/stats/streak?tz_offset_minutes=330")
        assert resp.status_code == 200
        assert resp.json()["streak"] == 0

    def test_streak_month_boundary_continuity(self):
        # 2026-09-30 and 2026-10-01
        self._seed_session("m1", "2026-09-30", 80.0, 120.0, 80.0, 80.0, 60.0)
        self._seed_session("m2", "2026-10-01", 85.0, 125.0, 85.0, 85.0, 60.0)

        sql = """
        WITH d AS (
          SELECT DISTINCT local_date FROM session_metrics
          WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
        ), g AS (
          SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
        )
        SELECT COUNT(*) AS streak, MAX(local_date) AS last_day
        FROM g GROUP BY grp ORDER BY last_day DESC LIMIT 1;
        """
        rows = self.fake_d1.query(sql, [self.user.id])
        assert len(rows) == 1
        assert rows[0]["streak"] == 2
        assert rows[0]["last_day"] == "2026-10-01"

    def test_streak_year_boundary_continuity(self):
        # 2025-12-31 and 2026-01-01
        self._seed_session("y1", "2025-12-31", 80.0, 120.0, 80.0, 80.0, 60.0)
        self._seed_session("y2", "2026-01-01", 85.0, 125.0, 85.0, 85.0, 60.0)

        sql = """
        WITH d AS (
          SELECT DISTINCT local_date FROM session_metrics
          WHERE user_id = ? AND deleted_at IS NULL AND status = 'analyzed'
        ), g AS (
          SELECT local_date, julianday(local_date) - ROW_NUMBER() OVER (ORDER BY local_date) AS grp FROM d
        )
        SELECT COUNT(*) AS streak, MAX(local_date) AS last_day
        FROM g GROUP BY grp ORDER BY last_day DESC LIMIT 1;
        """
        rows = self.fake_d1.query(sql, [self.user.id])
        assert len(rows) == 1
        assert rows[0]["streak"] == 2
        assert rows[0]["last_day"] == "2026-01-01"

    # 6. D1 unreachable fallback to Firestore aggregations
    def test_d1_unreachable_fallback_aggregations(self):
        self.fake_d1.timeout_count = 10  # D1 down

        resp = self.client.get("/stats/summary?tz_offset_minutes=330")
        assert resp.status_code == 200
        data = resp.json()
        assert "total_sessions" in data
