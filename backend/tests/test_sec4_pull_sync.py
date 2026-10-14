"""Section 4: Backend pull sync (GET /metrics/changes) tests."""
from datetime import datetime, timezone, timedelta
import sqlite3
import pytest
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from firestore import get_db
import main
import sys
import d1.d1_client
from models import User
from tests.test_sec2_post_sessions import LocalSqliteD1, InMemoryFirestoreDB


class TestSection4PullSync:
    @pytest.fixture(autouse=True)
    def setup_env(self, monkeypatch):
        self.fake_d1 = LocalSqliteD1()
        self.fake_db = InMemoryFirestoreDB()
        self.user_a = User(id="user_a_sync", email="sync_a@example.com")
        self.user_b = User(id="user_b_sync", email="sync_b@example.com")
        self.current_user = self.user_a

        monkeypatch.setattr(d1.d1_client, "get_d1_client", lambda: self.fake_d1)
        if "metrics.router" in sys.modules:
            monkeypatch.setattr(sys.modules["metrics.router"], "get_d1_client", lambda: self.fake_d1)
        main.app.dependency_overrides[get_current_user] = lambda: self.current_user
        main.app.dependency_overrides[get_db] = lambda: self.fake_db

        self.client = TestClient(main.app)
        yield
        main.app.dependency_overrides.clear()

    def _seed_row(self, sid, uid, updated_at, deleted_at=None):
        self.fake_d1.execute("""
            INSERT INTO session_metrics (
                id, user_id, mode, topic_or_question, duration_seconds, wpm,
                filler_word_count, pause_count, avg_pause_length, clarity_score,
                confidence_score, overall_score, status, created_at, local_date,
                tz_offset_minutes, updated_at, deleted_at
            ) VALUES (?, ?, 'interview', 'Topic', 60.0, 130.0, 2, 1, 0.5, 85.0, 80.0, 82.5,
                      'analyzed', '2026-10-09T10:00:00Z', '2026-10-09', 330, ?, ?);
        """, [sid, uid, updated_at, deleted_at])

    # 1. First call with null cursor returns all rows ordered by (updated_at, id)
    def test_null_cursor_returns_all_ordered(self):
        self._seed_row("s-3", self.user_a.id, "2026-10-09T12:00:00Z")
        self._seed_row("s-1", self.user_a.id, "2026-10-09T10:00:00Z")
        self._seed_row("s-2", self.user_a.id, "2026-10-09T11:00:00Z")

        resp = self.client.get("/metrics/changes")
        assert resp.status_code == 200
        data = resp.json()
        ids = [s["id"] for s in data["sessions"]]
        assert ids == ["s-1", "s-2", "s-3"]
        assert data["has_more"] is False
        assert data["next_cursor_updated_at"] == "2026-10-09T12:00:00Z"
        assert data["next_cursor_id"] == "s-3"

    # 2. Keyset cursor tie-breaker on identical updated_at
    def test_cursor_tie_breaker_on_same_updated_at(self):
        # 3 rows sharing the EXACT same updated_at
        same_time = "2026-10-09T12:00:00Z"
        self._seed_row("s-c", self.user_a.id, same_time)
        self._seed_row("s-a", self.user_a.id, same_time)
        self._seed_row("s-b", self.user_a.id, same_time)

        # Page 1: limit=2
        resp1 = self.client.get("/metrics/changes?limit=2")
        assert resp1.status_code == 200
        p1 = resp1.json()
        assert len(p1["sessions"]) == 2
        assert [s["id"] for s in p1["sessions"]] == ["s-a", "s-b"]
        assert p1["has_more"] is True

        # Page 2: pass cursor from Page 1
        cur_time = p1["next_cursor_updated_at"]
        cur_id = p1["next_cursor_id"]
        resp2 = self.client.get(f"/metrics/changes?cursor_updated_at={cur_time}&cursor_id={cur_id}&limit=2")
        assert resp2.status_code == 200
        p2 = resp2.json()
        assert len(p2["sessions"]) == 1
        assert p2["sessions"][0]["id"] == "s-c"
        assert p2["has_more"] is False

    # 3. Pagination over 450 rows with limit=200
    def test_pagination_450_rows(self):
        base_time = datetime(2026, 10, 1, 0, 0, 0, tzinfo=timezone.utc)
        for i in range(450):
            sid = f"sess_{i:04d}"
            # Evenly spread updated_at every minute
            upd_iso = (base_time + timedelta(minutes=i)).isoformat()
            self._seed_row(sid, self.user_a.id, upd_iso)

        all_received_ids = []
        has_more = True
        cur_updated = None
        cur_id = None
        page_count = 0

        while has_more:
            params = {"limit": 200}
            if cur_updated:
                params["cursor_updated_at"] = cur_updated
            if cur_id:
                params["cursor_id"] = cur_id
            resp = self.client.get("/metrics/changes", params=params)
            assert resp.status_code == 200
            data = resp.json()
            page_sessions = data["sessions"]
            all_received_ids.extend([s["id"] for s in page_sessions])
            has_more = data["has_more"]
            cur_updated = data["next_cursor_updated_at"]
            cur_id = data["next_cursor_id"]
            page_count += 1

        assert page_count == 3
        assert len(all_received_ids) == 450
        assert len(set(all_received_ids)) == 450

    # 4. Updated rows reappear after cursor, and tombstones returned
    def test_updated_rows_and_tombstones(self):
        self._seed_row("s-1", self.user_a.id, "2026-10-09T10:00:00Z")
        self._seed_row("s-2", self.user_a.id, "2026-10-09T11:00:00Z")

        # Initial sync
        resp = self.client.get("/metrics/changes")
        cur_updated = resp.json()["next_cursor_updated_at"]
        cur_id = resp.json()["next_cursor_id"]

        # Now soft-delete s-1 and update s-2 with newer timestamp
        newer_time = "2026-10-09T13:00:00Z"
        self.fake_d1.execute("""
            UPDATE session_metrics
            SET updated_at = ?, deleted_at = ?
            WHERE id = 's-1';
        """, [newer_time, newer_time])

        # Pull incremental changes
        resp2 = self.client.get(f"/metrics/changes?cursor_updated_at={cur_updated}&cursor_id={cur_id}")
        assert resp2.status_code == 200
        inc_data = resp2.json()
        assert len(inc_data["sessions"]) == 1
        tombstone = inc_data["sessions"][0]
        assert tombstone["id"] == "s-1"
        assert tombstone["deleted_at"] == newer_time

    # 5. user_achievements included
    def test_user_achievements_sync(self):
        now_iso = "2026-10-09T10:00:00Z"
        self.fake_d1.execute("""
            INSERT INTO user_achievements (user_id, achievement_key, unlocked_at, updated_at)
            VALUES (?, 'first_session', ?, ?);
        """, [self.user_a.id, now_iso, now_iso])

        resp = self.client.get("/metrics/changes")
        assert resp.status_code == 200
        ach = resp.json()["achievements"]
        assert len(ach) == 1
        assert ach[0]["achievement_key"] == "first_session"

    # 6. User A never receives User B rows
    def test_user_isolation(self):
        self._seed_row("s-user-b", self.user_b.id, "2026-10-09T10:00:00Z")
        self._seed_row("s-user-a", self.user_a.id, "2026-10-09T10:00:00Z")

        resp = self.client.get("/metrics/changes")
        assert resp.status_code == 200
        ids = [s["id"] for s in resp.json()["sessions"]]
        assert "s-user-a" in ids
        assert "s-user-b" not in ids

    # 7. Large page sizes capped
    def test_large_page_sizes_rejected_or_capped(self):
        resp = self.client.get("/metrics/changes?limit=1000")
        assert resp.status_code == 422  # Le 500 validation error
