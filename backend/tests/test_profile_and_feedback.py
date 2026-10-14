"""Tests for profile avatar upload, settings sync, account deletion, and feedback."""
import io
import pytest
from fastapi.testclient import TestClient

from main import app
from auth.utils import create_access_token
from models import User, USERS_COL, FEEDBACK_COL
from firestore import get_db

client = TestClient(app)


@pytest.fixture
def auth_headers():
    db = get_db()
    test_user_id = "test-prof-user-1"
    # Ensure test user in Firestore
    user = User(
        id=test_user_id,
        email="profile_test@example.com",
        full_name="Profile Tester",
        role_occupation="Software Engineer",
    )
    db.collection(USERS_COL).document(test_user_id).set(user.to_dict())

    token = create_access_token({"sub": test_user_id, "type": "access"})
    return {"Authorization": f"Bearer {token}"}


def test_get_and_patch_profile_settings(auth_headers):
    # GET /users/me
    res = client.get("/users/me", headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["email"] == "profile_test@example.com"
    assert "settings" in data

    # PATCH /users/me with settings
    settings_payload = {
        "daily_reminder": True,
        "reminder_time": "09:30",
        "reminder_days": [1, 2, 3, 4, 5],
        "weekly_goal": 5,
        "locale": "en",
    }
    patch_res = client.patch(
        "/users/me",
        json={"settings": settings_payload, "role_occupation": "Lead Engineer"},
        headers=auth_headers,
    )
    assert patch_res.status_code == 200
    updated_data = patch_res.json()
    assert updated_data["role_occupation"] == "Lead Engineer"
    assert updated_data["settings"]["weekly_goal"] == 5


def test_submit_feedback(auth_headers):
    payload = {
        "category": "Bug",
        "message": "The audio waveform is slightly lagging on low-end devices.",
        "app_version": "1.4.2",
        "device_info": {"os": "Android 14", "model": "Pixel 7"},
        "include_device_info": True,
    }
    res = client.post("/feedback", json=payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert "id" in data


def test_avatar_upload_and_retrieve(auth_headers):
    # Upload dummy PNG
    png_content = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    file = io.BytesIO(png_content)
    upload_res = client.post(
        "/users/me/avatar",
        files={"file": ("avatar.png", file, "image/png")},
        headers=auth_headers,
    )
    assert upload_res.status_code == 200
    user_data = upload_res.json()
    assert user_data["avatar_url"] is not None
    avatar_url = user_data["avatar_url"]

    # Retrieve avatar
    get_res = client.get(avatar_url)
    assert get_res.status_code == 200
    assert len(get_res.content) == len(png_content)


def test_delete_account_cascade(auth_headers):
    del_res = client.delete("/users/me", headers=auth_headers)
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"

    # Subsequent GET should fail because user document is deleted
    get_res = client.get("/users/me", headers=auth_headers)
    assert get_res.status_code == 401
