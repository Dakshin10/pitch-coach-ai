-- Migration 0002: Seed achievement catalog
INSERT OR IGNORE INTO achievement_catalog (key, title, description, icon_name, category) VALUES
('first_session', 'First Step', 'Complete your first practice session.', '🎤', 'milestone'),
('7_day_streak', '7-Day Streak', 'Practice 7 days in a row.', '🔥', 'streak'),
('50_sessions', '50 Sessions', 'Complete 50 practice sessions.', '🎯', 'milestone'),
('clarity_master', 'Clarity Master', 'Achieve a clarity score ≥ 85% in any session.', '💎', 'skill'),
('early_bird', 'Early Bird', 'Complete a session before 8:00 AM.', '🌅', 'habit');
