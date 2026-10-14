-- Migration 0001: Initial D1 schema for session metrics, fillers, and achievements
-- Matches schemas defined in Section 4.1

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
  status TEXT NOT NULL DEFAULT 'pending',  -- pending | uploading | analyzing | analyzed | failed
  created_at TEXT NOT NULL,                -- ISO-8601 UTC
  local_date TEXT NOT NULL,                -- 'YYYY-MM-DD' in the user's timezone
  tz_offset_minutes INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,                -- sync cursor
  deleted_at TEXT                          -- tombstone
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
