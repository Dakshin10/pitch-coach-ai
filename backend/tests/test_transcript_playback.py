"""Unit tests for transcript playback and word timestamp models."""
import unittest
from datetime import datetime, timezone

from models import PracticeSession
from schemas import SessionResult, WordTimestamp
from sessions.router import _to_result


class TestTranscriptPlayback(unittest.TestCase):
    def test_word_timestamp_schema(self):
        wt = WordTimestamp(word="hello", start=1.2, end=1.5)
        self.assertEqual(wt.word, "hello")
        self.assertEqual(wt.start, 1.2)
        self.assertEqual(wt.end, 1.5)

    def test_practice_session_serialization_with_word_timestamps(self):
        timestamps = [
            {"word": "welcome", "start": 0.2, "end": 0.6},
            {"word": "um", "start": 0.7, "end": 1.0},
            {"word": "everyone", "start": 1.1, "end": 1.5},
        ]
        session = PracticeSession(
            id="test-session-123",
            user_id="user-1",
            mode="interview",
            topic_or_question="Tell me about yourself",
            transcript="welcome um everyone",
            word_timestamps=timestamps,
            audio_offset_seconds=0.5,
        )

        d = session.to_dict()
        self.assertEqual(d["word_timestamps"], timestamps)
        self.assertEqual(d["audio_offset_seconds"], 0.5)

        restored = PracticeSession.from_dict(d)
        self.assertEqual(len(restored.word_timestamps), 3)
        self.assertEqual(restored.word_timestamps[1]["word"], "um")
        self.assertEqual(restored.audio_offset_seconds, 0.5)

    def test_to_result_backward_compatibility_empty_timestamps(self):
        session = PracticeSession(
            id="legacy-session",
            user_id="user-1",
            transcript="no timestamps here",
            word_timestamps=None,
        )
        result = _to_result(session)
        self.assertIsInstance(result, SessionResult)
        self.assertEqual(result.word_timestamps, [])
        self.assertEqual(result.audio_offset_seconds, 0.0)

    def test_to_result_with_word_timestamps(self):
        session = PracticeSession(
            id="new-session",
            user_id="user-1",
            transcript="hello like world",
            word_timestamps=[
                {"word": "hello", "start": 0.1, "end": 0.4},
                {"word": "like", "start": 0.5, "end": 0.8},
                {"word": "world", "start": 0.9, "end": 1.3},
            ],
            audio_offset_seconds=0.2,
        )
        result = _to_result(session)
        self.assertEqual(len(result.word_timestamps), 3)
        self.assertEqual(result.word_timestamps[1].word, "like")
        self.assertEqual(result.audio_offset_seconds, 0.2)

    def test_seek_offset_calculation(self):
        # Spec: Tapping seeks the audio player to `word.start - 0.3s` (clamped to 0)
        # With offset: `(word.start - offset) - 0.3s` (clamped to 0)
        def compute_seek(start: float, offset: float = 0.0) -> float:
            return max(0.0, (start - offset) - 0.3)

        # Early word (<0.3s) clamps to 0
        self.assertEqual(compute_seek(0.1, 0.0), 0.0)
        self.assertEqual(compute_seek(0.3, 0.0), 0.0)
        # Mid-sentence word at 2.5s seeks to 2.2s
        self.assertAlmostEqual(compute_seek(2.5, 0.0), 2.2)
        # With slide offset 1.0s, word at 3.0s seeks to 1.7s
        self.assertAlmostEqual(compute_seek(3.0, 1.0), 1.7)


if __name__ == "__main__":
    unittest.main()
