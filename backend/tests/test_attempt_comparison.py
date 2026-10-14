"""Unit tests for Feature 2: Attempt Comparison."""
import unittest
from datetime import datetime, timezone
import uuid

from models import PracticeSession
from schemas import SessionResult, SessionSummary, StartSessionRequest
from sessions.router import _to_result, _to_summary


class TestAttemptComparison(unittest.TestCase):
    def test_practice_session_parent_id_serialization(self):
        parent_id = str(uuid.uuid4())
        session = PracticeSession(
            id=str(uuid.uuid4()),
            user_id="user-123",
            parent_session_id=parent_id,
            mode="interview",
            topic_or_question="Tell me about yourself.",
            overall_score=85.0,
            wpm=140.0,
        )

        d = session.to_dict()
        self.assertEqual(d["parent_session_id"], parent_id)

        restored = PracticeSession.from_dict(d)
        self.assertEqual(restored.parent_session_id, parent_id)

    def test_session_result_and_summary_schemas(self):
        parent_id = "parent-sess-456"
        res = SessionResult(
            id="child-sess-789",
            parent_session_id=parent_id,
            mode="interview",
            topic_or_question="Tell me about yourself.",
            duration_seconds=60.0,
            wpm=135.0,
            filler_word_count=2,
            filler_word_breakdown={"um": 2},
            pause_count=2,
            avg_pause_length=0.7,
            clarity_score=85.0,
            confidence_score=88.0,
            overall_score=87.0,
            ai_feedback=[],
            created_at=datetime.now(timezone.utc),
            is_analyzed=True,
        )
        self.assertEqual(res.parent_session_id, parent_id)

        session = PracticeSession(
            id="child-sess-789",
            parent_session_id=parent_id,
            mode="interview",
            topic_or_question="Tell me about yourself.",
            duration_seconds=60.0,
            wpm=135.0,
            filler_word_count=2,
            pause_count=2,
            avg_pause_length=0.7,
            clarity_score=85.0,
            confidence_score=88.0,
            overall_score=87.0,
            is_analyzed=True,
        )
        summary = _to_summary(session)
        self.assertEqual(summary.parent_session_id, parent_id)

        to_res = _to_result(session)
        self.assertEqual(to_res.parent_session_id, parent_id)

    def test_attempt_comparison_delta_logic(self):
        # Helper that computes attempt deltas matching Feature 2 specs
        def compute_deltas(current: dict, parent: dict):
            # Only compare if topic matches
            if current["topic"] != parent["topic"]:
                return None

            # 1. Overall score delta
            score_delta = round(current["overall_score"] - parent["overall_score"], 1)

            # 2. Fillers per 100 words delta
            # total words = (wpm * duration / 60)
            def filler_rate(sess):
                total_words = max(1.0, (sess["wpm"] * sess["duration_seconds"]) / 60.0)
                return (sess["filler_count"] / total_words) * 100.0

            current_filler_rate = filler_rate(current)
            parent_filler_rate = filler_rate(parent)
            filler_rate_delta = round(current_filler_rate - parent_filler_rate, 2)

            # 3. WPM relative to the 120-160 band
            def band_distance(wpm):
                if 120.0 <= wpm <= 160.0:
                    return 0.0
                elif wpm < 120.0:
                    return 120.0 - wpm
                else:
                    return wpm - 160.0

            cur_dist = band_distance(current["wpm"])
            par_dist = band_distance(parent["wpm"])
            wpm_closer = cur_dist < par_dist
            wpm_optimal = cur_dist == 0.0

            # 4. Pause count delta
            pause_delta = current["pause_count"] - parent["pause_count"]

            return {
                "score_delta": score_delta,
                "filler_rate_delta": filler_rate_delta,
                "wpm_optimal": wpm_optimal,
                "wpm_closer": wpm_closer,
                "pause_delta": pause_delta,
            }

        parent_take = {
            "topic": "Describe a difficult project",
            "overall_score": 72.0,
            "wpm": 105.0,  # 15 WPM below optimal band
            "duration_seconds": 60.0,
            "filler_count": 8,
            "pause_count": 6,
        }

        # Attempt 2: improved score, faster pace entering optimal band, fewer fillers
        attempt_2 = {
            "topic": "Describe a difficult project",
            "overall_score": 84.0,
            "wpm": 135.0,  # inside [120, 160]
            "duration_seconds": 60.0,
            "filler_count": 3,
            "pause_count": 4,
        }

        deltas = compute_deltas(attempt_2, parent_take)
        self.assertIsNotNone(deltas)
        self.assertEqual(deltas["score_delta"], 12.0)
        self.assertLess(deltas["filler_rate_delta"], 0.0)  # Improved filler rate
        self.assertTrue(deltas["wpm_optimal"])  # Inside optimal band
        self.assertTrue(deltas["wpm_closer"])
        self.assertEqual(deltas["pause_delta"], -2)  # 2 fewer pauses

        # Mismatched prompt should not allow comparison
        attempt_mismatched = {
            "topic": "Why should we hire you?",
            "overall_score": 85.0,
            "wpm": 130.0,
            "duration_seconds": 60.0,
            "filler_count": 2,
            "pause_count": 3,
        }
        self.assertIsNone(compute_deltas(attempt_mismatched, parent_take))


if __name__ == "__main__":
    unittest.main()
