"""Section 1: Schema and migration tests.

Tests verify:
- D1 migrations apply to empty DB and create spec tables, columns, indexes.
- Local SQLite migrations apply to empty DB and create identical shared tables.
- D1 and local schemas for session_metrics, session_fillers, and user_achievements are identical.
- FOREIGN KEY ON DELETE CASCADE on session_fillers.
- No 'users' table exists in SQL.
- Test whether 'filler_word_breakdown' is present in Firestore session document generation.
"""
import os
import sqlite3
import pytest
from datetime import datetime, timezone
from models import PracticeSession


D1_MIGRATIONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "d1", "migrations"))


def _apply_d1_migrations(conn: sqlite3.Connection):
    conn.execute("PRAGMA foreign_keys = ON;")
    migration_files = sorted([f for f in os.listdir(D1_MIGRATIONS_DIR) if f.endswith(".sql")])
    for mf in migration_files:
        with open(os.path.join(D1_MIGRATIONS_DIR, mf), "r", encoding="utf-8") as f:
            sql = f.read()
            conn.executescript(sql)


def _apply_local_migrations(conn: sqlite3.Connection):
    """Replicates LocalDatabaseService._migrationV1 in Python."""
    conn.execute("PRAGMA foreign_keys = ON;")
    conn.executescript("""
      CREATE TABLE IF NOT EXISTS session_metrics (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        mode TEXT NOT NULL DEFAULT 'interview',
        topic_or_question TEXT NOT NULL,
        duration_seconds REAL NOT NULL DEFAULT 0,
        wpm REAL NOT NULL DEFAULT 0,
        filler_word_count INTEGER NOT NULL DEFAULT 0,
        pause_count INTEGER NOT NULL DEFAULT 0,
        avg_pause_length REAL NOT NULL DEFAULT 0,
        clarity_score REAL NOT NULL DEFAULT 0,
        confidence_score REAL NOT NULL DEFAULT 0,
        overall_score REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_sm_user_date ON session_metrics(user_id, local_date DESC);
      CREATE INDEX IF NOT EXISTS idx_sm_user_updated ON session_metrics(user_id, updated_at, id);

      CREATE TABLE IF NOT EXISTS session_fillers (
        session_id TEXT NOT NULL,
        filler_word TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (session_id, filler_word),
        FOREIGN KEY (session_id) REFERENCES session_metrics(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS achievement_catalog (
        key TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS user_achievements (
        user_id TEXT NOT NULL,
        achievement_key TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, achievement_key),
        FOREIGN KEY (achievement_key) REFERENCES achievement_catalog(key)
      );

      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        local_audio_path TEXT,
        state TEXT NOT NULL DEFAULT 'queued',
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_state (
        user_id TEXT PRIMARY KEY,
        last_cursor_updated_at TEXT,
        last_cursor_id TEXT
      );
    """)


def _get_table_columns(conn: sqlite3.Connection, table_name: str):
    cursor = conn.cursor()
    cursor.execute(f"PRAGMA table_info({table_name});")
    # Returns (cid, name, type, notnull, dflt_value, pk)
    return {row[1]: {"type": row[2].upper(), "notnull": row[3], "pk": row[5]} for row in cursor.fetchall()}


def _get_table_names(conn: sqlite3.Connection):
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    return {row[0] for row in cursor.fetchall()}


def _get_indexes(conn: sqlite3.Connection, table_name: str):
    cursor = conn.cursor()
    cursor.execute(f"PRAGMA index_list({table_name});")
    return {row[1] for row in cursor.fetchall() if not row[1].startswith("sqlite_autoindex")}


class TestSchemaAndMigrations:
    def test_d1_migrations_apply_and_match_spec(self):
        conn = sqlite3.connect(":memory:")
        _apply_d1_migrations(conn)

        tables = _get_table_names(conn)
        expected_d1_tables = {"session_metrics", "session_fillers", "achievement_catalog", "user_achievements"}
        assert expected_d1_tables == tables, f"D1 tables mismatch: {tables}"

        # Indexes on session_metrics
        sm_indexes = _get_indexes(conn, "session_metrics")
        assert "idx_sm_user_date" in sm_indexes
        assert "idx_sm_user_updated" in sm_indexes

        # Assert no 'users' table
        assert "users" not in tables, "Defect: 'users' table found in SQL!"

    def test_local_migrations_apply_and_match_spec(self):
        conn = sqlite3.connect(":memory:")
        _apply_local_migrations(conn)

        tables = _get_table_names(conn)
        expected_local_tables = {
            "session_metrics", "session_fillers", "achievement_catalog",
            "user_achievements", "sync_outbox", "sync_state"
        }
        assert expected_local_tables == tables, f"Local tables mismatch: {tables}"
        assert "users" not in tables

    def test_d1_and_local_shared_schemas_are_identical(self):
        d1_conn = sqlite3.connect(":memory:")
        _apply_d1_migrations(d1_conn)

        local_conn = sqlite3.connect(":memory:")
        _apply_local_migrations(local_conn)

        shared_tables = ["session_metrics", "session_fillers", "achievement_catalog", "user_achievements"]
        for tbl in shared_tables:
            d1_cols = _get_table_columns(d1_conn, tbl)
            local_cols = _get_table_columns(local_conn, tbl)
            assert d1_cols == local_cols, f"Columns for table {tbl} differ: D1={d1_cols} vs Local={local_cols}"

    def test_session_fillers_primary_key_and_cascade_delete(self):
        conn = sqlite3.connect(":memory:")
        _apply_d1_migrations(conn)
        conn.execute("PRAGMA foreign_keys = ON;")

        # Insert parent session metric
        now_iso = datetime.now(timezone.utc).isoformat()
        conn.execute("""
            INSERT INTO session_metrics (id, user_id, topic_or_question, created_at, local_date, updated_at)
            VALUES ('sess-1', 'user-1', 'Topic 1', ?, '2026-10-09', ?);
        """, (now_iso, now_iso))

        # Insert filler
        conn.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES ('sess-1', 'um', 3);")

        # Duplicate (session_id, filler_word) should violate primary key
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute("INSERT INTO session_fillers (session_id, filler_word, count) VALUES ('sess-1', 'um', 5);")

        # Deleting session_metric should CASCADE delete session_fillers
        conn.execute("DELETE FROM session_metrics WHERE id = 'sess-1';")
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM session_fillers WHERE session_id = 'sess-1';")
        count = cur.fetchone()[0]
        assert count == 0, f"Cascade delete failed, found {count} leftover fillers"

    def test_firestore_doc_must_not_contain_filler_word_breakdown(self):
        """Spec Rule: Do not store filler_word_breakdown in Firestore.
        It lives only in session_fillers (SQL).
        """
        session = PracticeSession(
            id="test-sid",
            user_id="user-1",
            filler_word_count=4,
            filler_word_breakdown={"um": 3, "uh": 1},
        )
        doc = session.to_dict()
        # Assert whether filler_word_breakdown is present in Firestore doc dict
        assert "filler_word_breakdown" not in doc, (
            "DEFECT: filler_word_breakdown found in Firestore session doc dictionary!"
        )
