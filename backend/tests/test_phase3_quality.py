"""Unit tests for Phase 3: Backend Quality (Stats math, PyJWT & bcrypt, Groq key helper, Ownership)."""
import unittest
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient

from auth.utils import hash_password, verify_password, create_access_token, decode_token
from config import get_groq_key, get_settings
from main import app
from models import PracticeSession, SlideDeck, User
from stats.router import _streak, _filler_reduction
from auth.dependencies import get_current_user


class TestPhase3Quality(unittest.TestCase):

    def test_bcrypt_hashing_and_verification(self):
        """Verify direct bcrypt hashing correctly verifies matches and rejects mismatches."""
        raw_pass = "SuperSecret123!"
        hashed = hash_password(raw_pass)

        self.assertTrue(verify_password(raw_pass, hashed))
        self.assertFalse(verify_password("WrongPassword!", hashed))
        self.assertFalse(verify_password("", hashed))

    def test_pyjwt_token_creation_and_decoding(self):
        """Verify PyJWT generates valid JWTs and decodes correctly."""
        payload = {"sub": "user_abc", "custom": "field"}
        token = create_access_token(payload)

        decoded = decode_token(token)
        self.assertIsNotNone(decoded)
        self.assertEqual(decoded["sub"], "user_abc")
        self.assertEqual(decoded["type"], "access")
        self.assertEqual(decoded["custom"], "field")

        # Invalid token returns None
        self.assertIsNone(decode_token("invalid.token.string"))

    def test_streak_calculation(self):
        """Verify consecutive days streak math."""
        today = datetime.now(timezone.utc)
        yesterday = today - timedelta(days=1)
        two_days_ago = today - timedelta(days=2)
        four_days_ago = today - timedelta(days=4)

        # Empty sessions -> 0
        self.assertEqual(_streak([]), 0)

        # Session today -> 1
        s_today = PracticeSession(id="1", created_at=today)
        self.assertEqual(_streak([s_today]), 1)

        # Session yesterday only -> 1 (streak still alive)
        s_yest = PracticeSession(id="2", created_at=yesterday)
        self.assertEqual(_streak([s_yest]), 1)

        # Sessions today, yesterday, 2 days ago -> 3
        s_2ago = PracticeSession(id="3", created_at=two_days_ago)
        self.assertEqual(_streak([s_today, s_yest, s_2ago]), 3)

        # Broken streak (today and 4 days ago) -> 1
        s_broken = PracticeSession(id="4", created_at=four_days_ago)
        self.assertEqual(_streak([s_today, s_broken]), 1)

    def test_filler_reduction_calculation(self):
        """Verify filler reduction percentage calculation."""
        t1 = datetime(2026, 1, 1, tzinfo=timezone.utc)
        t2 = datetime(2026, 1, 2, tzinfo=timezone.utc)
        t3 = datetime(2026, 1, 3, tzinfo=timezone.utc)
        t4 = datetime(2026, 1, 4, tzinfo=timezone.utc)

        # < 2 sessions -> 0.0
        s1 = PracticeSession(id="1", created_at=t1, filler_word_count=10)
        self.assertEqual(_filler_reduction([s1]), 0.0)

        # First half: avg 10. Second half: avg 5 -> 50.0% reduction
        s2 = PracticeSession(id="2", created_at=t2, filler_word_count=10)
        s3 = PracticeSession(id="3", created_at=t3, filler_word_count=5)
        s4 = PracticeSession(id="4", created_at=t4, filler_word_count=5)
        self.assertEqual(_filler_reduction([s1, s2, s3, s4]), 50.0)

        # Fillers increased: first half avg 4, second half avg 8 -> -100.0%
        s_inc1 = PracticeSession(id="a", created_at=t1, filler_word_count=4)
        s_inc2 = PracticeSession(id="b", created_at=t2, filler_word_count=8)
        self.assertEqual(_filler_reduction([s_inc1, s_inc2]), -100.0)

    def test_groq_key_unification(self):
        """Verify get_groq_key falls back and differentiates audio when set."""
        settings = get_settings()
        old_general = settings.GROQ_API_KEY
        old_audio = settings.GROQ_AUDIO_API_KEY

        try:
            settings.GROQ_API_KEY = "key_general"
            settings.GROQ_AUDIO_API_KEY = ""
            self.assertEqual(get_groq_key("audio"), "key_general")
            self.assertEqual(get_groq_key(), "key_general")

            settings.GROQ_AUDIO_API_KEY = "key_audio"
            self.assertEqual(get_groq_key("audio"), "key_audio")
            self.assertEqual(get_groq_key(), "key_general")
        finally:
            settings.GROQ_API_KEY = old_general
            settings.GROQ_AUDIO_API_KEY = old_audio

    def test_ownership_check_enforced(self):
        """Verify attempting to access another user's session or deck returns 404."""
        client = TestClient(app)
        owner_user = User(id="user_owner", email="owner@test.com")
        other_user = User(id="user_attacker", email="attacker@test.com")

        # Override dependency to act as other_user
        app.dependency_overrides[get_current_user] = lambda: other_user
        try:
            # 1. Session owned by user_owner
            mock_session = PracticeSession(
                id="session_victim",
                user_id="user_owner",
                is_analyzed=True,
            )
            with patch("sessions.router.get_db") as mock_db:
                mock_doc = MagicMock()
                mock_doc.exists = True
                mock_doc.to_dict.return_value = mock_session.to_dict()
                mock_db.return_value.collection.return_value.document.return_value.get.return_value = mock_doc

                resp = client.get("/sessions/session_victim")
                self.assertEqual(resp.status_code, 404)

            # 2. Slide deck owned by user_owner
            mock_deck = SlideDeck(
                id="deck_victim",
                user_id="user_owner",
                status="done",
            )
            with patch("slides.router.deck_store.get", return_value=mock_deck):
                resp = client.get("/slides/deck_victim")
                self.assertEqual(resp.status_code, 404)

                resp_status = client.get("/slides/deck_victim/status")
                self.assertEqual(resp_status.status_code, 404)

        finally:
            app.dependency_overrides.clear()


if __name__ == "__main__":
    unittest.main()
