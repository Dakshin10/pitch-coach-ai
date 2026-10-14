import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone

from achievements.service import evaluate_user_achievements


class TestPhase5Achievements(unittest.TestCase):
    def test_unlock_first_session_and_clarity_master(self):
        mock_d1 = MagicMock()
        mock_d1.is_configured = True

        # Initially no unlocked achievements
        # count query returns 1 session
        # clarity query returns 1 row (score >= 85)
        # early bird returns empty
        # streak returns 1
        def mock_query(sql, params):
            if "SELECT achievement_key FROM user_achievements" in sql:
                return []
            elif "SELECT COUNT(*) AS total FROM session_metrics" in sql:
                return [{"total": 1}]
            elif "clarity_score >= 85" in sql:
                return [{"1": 1}]
            elif "early_bird" in sql or "480" in sql:
                return []
            elif "WITH d AS" in sql:
                return [{"max_streak": 1}]
            return []

        mock_d1.query.side_effect = mock_query

        unlocked = evaluate_user_achievements("user-test-1", d1_client=mock_d1, db=None)
        self.assertIn("first_session", unlocked)
        self.assertIn("clarity_master", unlocked)
        self.assertNotIn("50_sessions", unlocked)
        self.assertNotIn("7_day_streak", unlocked)
        self.assertNotIn("early_bird", unlocked)

        # Verify batch upsert into D1 was called
        mock_d1.batch.assert_called_once()
        batch_args = mock_d1.batch.call_args[0][0]
        self.assertEqual(len(batch_args), 2)
        keys_inserted = [args[1][1] for args in batch_args]
        self.assertIn("first_session", keys_inserted)
        self.assertIn("clarity_master", keys_inserted)

    def test_unlock_7_day_streak(self):
        mock_d1 = MagicMock()
        mock_d1.is_configured = True

        def mock_query(sql, params):
            if "SELECT achievement_key FROM user_achievements" in sql:
                return [{"achievement_key": "first_session"}]
            elif "SELECT COUNT(*) AS total FROM session_metrics" in sql:
                return [{"total": 7}]
            elif "clarity_score >= 85" in sql:
                return []
            elif "early_bird" in sql or "480" in sql:
                return []
            elif "WITH d AS" in sql:
                return [{"max_streak": 7}]
            return []

        mock_d1.query.side_effect = mock_query

        unlocked = evaluate_user_achievements("user-streak-7", d1_client=mock_d1, db=None)
        self.assertEqual(unlocked, ["7_day_streak"])

    def test_already_unlocked_not_re_added(self):
        mock_d1 = MagicMock()
        mock_d1.is_configured = True

        def mock_query(sql, params):
            if "SELECT achievement_key FROM user_achievements" in sql:
                return [
                    {"achievement_key": "first_session"},
                    {"achievement_key": "50_sessions"},
                    {"achievement_key": "clarity_master"},
                    {"achievement_key": "early_bird"},
                    {"achievement_key": "7_day_streak"},
                ]
            elif "SELECT COUNT(*) AS total FROM session_metrics" in sql:
                return [{"total": 60}]
            return []

        mock_d1.query.side_effect = mock_query

        unlocked = evaluate_user_achievements("user-full", d1_client=mock_d1, db=None)
        self.assertEqual(unlocked, [])
        mock_d1.batch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
