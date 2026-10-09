"""Unit tests for Phase 2: Stats on Cloudflare D1 with Firestore aggregation fallbacks."""
import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone, timedelta

from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from d1.d1_client import D1ConnectionError, get_d1_client
from firestore import get_db
from models import User
import main


class TestPhase2StatsD1(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)
        self.mock_user = User(
            id="test-stats-user-123",
            email="stats@pitchcoach.com",
            full_name="Stats Tester",
        )
        self.mock_db = MagicMock()
        self.mock_d1 = MagicMock()
        self.mock_d1.is_configured = True

        main.app.dependency_overrides[get_current_user] = lambda: self.mock_user
        main.app.dependency_overrides[get_db] = lambda: self.mock_db

    def tearDown(self):
        main.app.dependency_overrides.clear()

    @patch("stats.router.get_d1_client")
    def test_summary_d1_success(self, mock_get_d1):
        """When D1 is healthy, /stats/summary calculates aggregates from D1."""
        mock_get_d1.return_value = self.mock_d1
        today = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")

        # Mock query calls:
        # 1: summary_sql
        # 2: streak_sql
        # 3: filler_sql
        self.mock_d1.query.side_effect = [
            [{"total_sessions": 8, "avg_confidence": 84.5}],
            [{"streak": 4, "last_day": today}],
            [{"first_half_avg": 4.0, "second_half_avg": 2.0}],
        ]

        resp = self.client.get("/stats/summary?tz_offset_minutes=330")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        self.assertEqual(data["total_sessions"], 8)
        self.assertEqual(data["avg_confidence"], 84.5)
        self.assertEqual(data["streak_days"], 4)
        self.assertEqual(data["filler_reduction_pct"], 50.0)

    @patch("stats.router.get_d1_client")
    def test_summary_fallback_to_firestore_aggregations(self, mock_get_d1):
        """When D1 is down, falls back to Firestore aggregation queries (count() and avg())."""
        mock_get_d1.return_value = self.mock_d1
        self.mock_d1.query.side_effect = D1ConnectionError("D1 cluster unreachable")

        # Mock Firestore aggregation result
        mock_agg_item_count = MagicMock()
        mock_agg_item_count.alias = "count"
        mock_agg_item_count.value = 5

        mock_agg_item_avg = MagicMock()
        mock_agg_item_avg.alias = "avg_conf"
        mock_agg_item_avg.value = 82.4

        mock_query = self.mock_db.collection.return_value.where.return_value.where.return_value.where.return_value
        mock_query.count.return_value.avg.return_value.get.return_value = [[mock_agg_item_count, mock_agg_item_avg]]

        today = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")
        recent_doc = MagicMock()
        recent_doc.to_dict.return_value = {
            "local_date": today,
            "created_at": datetime.now(timezone.utc),
        }
        mock_query.order_by.return_value.limit.return_value.get.return_value = [recent_doc]

        resp = self.client.get("/stats/summary?tz_offset_minutes=330")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        self.assertEqual(data["total_sessions"], 5)
        self.assertEqual(data["avg_confidence"], 82.4)
        self.assertEqual(data["streak_days"], 1)

    @patch("stats.router.get_d1_client")
    def test_trend_d1_success(self, mock_get_d1):
        """When D1 is healthy, /stats/trend queries D1 by local_date."""
        mock_get_d1.return_value = self.mock_d1
        today = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")

        self.mock_d1.query.return_value = [
            {"local_date": today, "confidence": 88.0, "score": 90.0, "wpm": 130.0, "clarity": 85.0},
        ]

        resp = self.client.get("/stats/trend?range=week&tz_offset_minutes=330")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]["confidence"], 88.0)

    @patch("stats.router.get_d1_client")
    def test_streak_gaps_and_islands_active(self, mock_get_d1):
        """Active streak: last_day is today in user timezone."""
        mock_get_d1.return_value = self.mock_d1
        today = (datetime.now(timezone.utc) + timedelta(minutes=330)).strftime("%Y-%m-%d")

        self.mock_d1.query.return_value = [
            {"streak": 7, "last_day": today},
        ]

        resp = self.client.get("/stats/streak?tz_offset_minutes=330")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["streak"], 7)
        self.assertEqual(data["last_day"], today)

    @patch("stats.router.get_d1_client")
    def test_streak_gaps_and_islands_broken(self, mock_get_d1):
        """Broken streak: last_day was 3 days ago in user timezone."""
        mock_get_d1.return_value = self.mock_d1
        three_days_ago = (datetime.now(timezone.utc) + timedelta(minutes=330) - timedelta(days=3)).strftime("%Y-%m-%d")

        self.mock_d1.query.return_value = [
            {"streak": 5, "last_day": three_days_ago},
        ]

        resp = self.client.get("/stats/streak?tz_offset_minutes=330")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["streak"], 0)
        self.assertEqual(data["last_day"], three_days_ago)


if __name__ == "__main__":
    unittest.main()
