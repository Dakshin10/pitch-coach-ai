-- Migration 0002: Seed achievement catalog
INSERT OR IGNORE INTO achievement_catalog (key, title, description, icon_name, category) VALUES
('first_session', 'First Step', 'Complete your first practice session.', 'mic', 'milestone'),
('7_day_streak', '7-Day Streak', 'Practice 7 days in a row.', 'fire', 'streak'),
('50_sessions', '50 Sessions', 'Complete 50 practice sessions.', 'target', 'milestone'),
('clarity_master', 'Clarity Master', 'Achieve a clarity score ≥ 85% in any session.', 'diamond', 'skill'),
('early_bird', 'Early Bird', 'Complete a session before 8:00 AM.', 'sunrise', 'habit');

