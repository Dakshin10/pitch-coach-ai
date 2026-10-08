"""Tests for Phase 1 critical security: SECRET_KEY validation, admin-only cleanup, auth hardening & rate limiting."""
import unittest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient

from auth.dependencies import get_current_user
from config import Settings, INSECURE_SECRET_KEYS
from models import User
from schemas import SignupRequest, LoginRequest
import main


class TestSecretKeyValidation(unittest.TestCase):
    def test_insecure_default_secret_raises_value_error(self):
        for bad_secret in INSECURE_SECRET_KEYS:
            with self.assertRaises(ValueError) as ctx:
                Settings(SECRET_KEY=bad_secret)
            self.assertIn("Insecure or missing SECRET_KEY", str(ctx.exception))

    def test_secure_secret_accepted(self):
        s = Settings(SECRET_KEY="a" * 64)
        self.assertEqual(s.SECRET_KEY, "a" * 64)


class TestPhase1SecurityEndpoints(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)

    def test_duplicate_slides_api_prefix_removed(self):
        """Verify /api/slides/* was removed from router mounts while /slides/* remains."""
        # /api/slides should 404 now
        res_old = self.client.get("/api/slides/non-existent-id")
        self.assertEqual(res_old.status_code, 404)

        # /slides routes exist (requires auth -> 401, not 404)
        res_new = self.client.get("/slides/non-existent-id")
        self.assertEqual(res_new.status_code, 401)

    def test_password_length_validation(self):
        """Passwords under 8 chars should be rejected with 422."""
        res = self.client.post("/auth/signup", json={
            "email": "test@example.com",
            "password": "short",
            "full_name": "Test User",
        })
        self.assertEqual(res.status_code, 422)

    def test_email_normalization_schema(self):
        """Email should be lowercased and whitespace-trimmed."""
        req = SignupRequest(
            email="  User.NAME@Example.COM  ",
            password="securepassword123",
            full_name="User Name",
        )
        self.assertEqual(req.email, "user.name@example.com")

        login_req = LoginRequest(
            email="  USER.NAME@Example.COM  ",
            password="securepassword123",
        )
        self.assertEqual(login_req.email, "user.name@example.com")

    def tearDown(self):
        main.app.dependency_overrides.clear()

    @patch("slides.router.deck_store")
    def test_cleanup_non_admin_forbidden(self, mock_store):
        """Non-admin user calling /slides/cleanup gets 403 Forbidden."""
        normal_user = User(
            id="usr_normal_123",
            email="normal@example.com",
            full_name="Normal User",
            is_guest=False,
        )
        main.app.dependency_overrides[get_current_user] = lambda: normal_user

        with patch("slides.router.get_settings") as mock_settings:
            mock_settings.return_value.admin_user_id_list = ["admin_id_999"]
            res = self.client.post("/slides/cleanup")
            self.assertEqual(res.status_code, 403)
            self.assertIn("Admin privileges required", res.json()["detail"])
            mock_store.cleanup_expired.assert_not_called()

    @patch("slides.router.deck_store")
    def test_cleanup_admin_allowed(self, mock_store):
        """Admin user calling /slides/cleanup succeeds."""
        admin_user = User(
            id="admin_id_999",
            email="admin@example.com",
            full_name="Admin User",
            is_guest=False,
        )
        mock_store.cleanup_expired.return_value = 5
        main.app.dependency_overrides[get_current_user] = lambda: admin_user

        with patch("slides.router.get_settings") as mock_settings:
            mock_settings.return_value.admin_user_id_list = ["admin_id_999"]
            res = self.client.post("/slides/cleanup?ttl_days=14")
            self.assertEqual(res.status_code, 200)
            self.assertEqual(res.json()["deleted_count"], 5)
            mock_store.cleanup_expired.assert_called_once_with(14)

    def test_cleanup_ttl_days_bounds(self):
        """ttl_days must be between 1 and 365."""
        admin_user = User(
            id="admin_id_999",
            email="admin@example.com",
            full_name="Admin User",
            is_guest=False,
        )
        main.app.dependency_overrides[get_current_user] = lambda: admin_user
        with patch("slides.router.get_settings") as mock_settings:
            mock_settings.return_value.admin_user_id_list = ["admin_id_999"]
            res_invalid = self.client.post("/slides/cleanup?ttl_days=0")
            self.assertEqual(res_invalid.status_code, 422)

            res_excessive = self.client.post("/slides/cleanup?ttl_days=400")
            self.assertEqual(res_excessive.status_code, 422)

    def test_rate_limiting_guest_endpoint(self):
        """Verify slowapi triggers 429 after exceeding limit."""
        # /auth/guest limit is 10/hour
        with patch("auth.router.get_db") as mock_db:
            fake_doc = MagicMock()
            mock_db.return_value.collection.return_value.document.return_value = fake_doc
            
            responses = []
            for _ in range(12):
                responses.append(self.client.post("/auth/guest"))
            
            status_codes = [r.status_code for r in responses]
            self.assertIn(429, status_codes)


if __name__ == "__main__":
    unittest.main()
