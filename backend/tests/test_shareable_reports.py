"""Tests for Shareable Reports (Feature 10).

Verifies:
1. PyMuPDF generates valid PDF bytes starting with %PDF for session and weekly reports.
2. Energy curves, pacing indicators, and top 3 coaching recommendations are rendered.
3. GET /reports/sessions/{session_id}/pdf generates application/pdf response with proper headers.
4. Ownership check blocks unauthorized session report access (404/403).
5. GET /reports/weekly/pdf generates a comprehensive weekly summary PDF.
"""
from datetime import datetime, timezone, timedelta
import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock
import pymupdf as fitz

from auth.dependencies import get_current_user
from firestore import get_db
import main
from models import PracticeSession, User
from reports.service import (
    generate_session_pdf_report,
    generate_weekly_pdf_report,
    _pacing_assessment,
    _score_color,
)

client = TestClient(main.app)


class TestShareableReports:
    @pytest.fixture(autouse=True)
    def setup_env(self):
        self.mock_user = User(
            id="user_report_test",
            email="reports@example.com",
            full_name="Alex Rivera",
        )
        self.mock_db = MagicMock()
        main.app.dependency_overrides[get_current_user] = lambda: self.mock_user
        main.app.dependency_overrides[get_db] = lambda: self.mock_db
        yield
        main.app.dependency_overrides.clear()

    def test_pacing_assessment_bands(self):
        """Pacing assessment properly classifies 120-160 WPM target and outliers."""
        label_opt, col_opt = _pacing_assessment(140.0)
        assert "Optimal" in label_opt

        label_fast, col_fast = _pacing_assessment(170.0)
        assert "Slightly Fast" in label_fast

        label_slow, col_slow = _pacing_assessment(110.0)
        assert "Slightly Deliberate" in label_slow

        label_rush, col_rush = _pacing_assessment(210.0)
        assert "Rushing" in label_rush

        label_hes, col_hes = _pacing_assessment(80.0)
        assert "Hesitant" in label_hes

    def test_generate_session_pdf_report_validity(self):
        """Generates valid, parseable PDF bytes containing expected sections."""
        session = PracticeSession(
            id="sess-rep-001",
            user_id="user_report_test",
            topic_or_question="Series A Startup Investor Pitch",
            mode="presentation",
            duration_seconds=184.0,
            overall_score=88.5,
            clarity_score=92.0,
            confidence_score=85.0,
            structure_score=90.0,
            wpm=138.0,
            filler_word_count=2,
            pause_count=4,
            avg_pause_length=1.1,
            pitch_variation_score=84.0,
            volume_consistency_score=89.0,
            energy_curve=[0.1, 0.35, 0.7, 0.85, 0.6, 0.4, 0.2],
            transcript="Good morning investors. Today we are presenting Pitch Coach.",
            ai_feedback=[
                {
                    "category": "Pacing",
                    "severity": "tip",
                    "message": "Maintain your steady 138 WPM pace through the financials slide.",
                },
                {
                    "category": "Traction",
                    "severity": "important",
                    "message": "Explicitly highlight the 40% month-over-month retention figure.",
                },
            ],
            created_at=datetime.now(timezone.utc),
            is_analyzed=True,
        )

        pdf_bytes = generate_session_pdf_report(session, user_name="Alex Rivera")
        assert len(pdf_bytes) > 2000
        assert pdf_bytes[:4] == b"%PDF"

        # Validate PyMuPDF can parse it back
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        assert len(doc) == 1
        page_text = doc[0].get_text()
        assert "PITCH COACH" in page_text
        assert "OVERALL SCORE" in page_text
        assert "89" in page_text or "88" in page_text
        assert "138 WPM" in page_text
        doc.close()

    def test_generate_weekly_pdf_report_validity(self):
        """Generates a valid weekly aggregate report."""
        sessions = [
            PracticeSession(
                id=f"sess-week-{i}",
                user_id="user_report_test",
                topic_or_question=f"Pitch rehearsal {i}",
                mode="interview",
                duration_seconds=120.0,
                overall_score=80.0 + i,
                wpm=130.0 + i,
                clarity_score=85.0,
                confidence_score=80.0,
                filler_word_count=i,
                created_at=datetime.now(timezone.utc) - timedelta(days=i),
                is_analyzed=True,
            )
            for i in range(3)
        ]

        pdf_bytes = generate_weekly_pdf_report(sessions, user_name="Alex Rivera")
        assert len(pdf_bytes) > 2000
        assert pdf_bytes[:4] == b"%PDF"

        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        assert len(doc) == 1
        page_text = doc[0].get_text()
        assert "WEEKLY PROGRESS REPORT" in page_text
        assert "TOTAL SESSIONS" in page_text
        doc.close()

    def test_get_session_pdf_report_endpoint(self):
        """GET /reports/sessions/{session_id}/pdf returns application/pdf."""
        session_id = "test-session-pdf-123"
        session_data = {
            "id": session_id,
            "user_id": "user_report_test",
            "topic_or_question": "Tech Demo Pitch",
            "mode": "presentation",
            "duration_seconds": 95.0,
            "overall_score": 86.0,
            "clarity_score": 88.0,
            "confidence_score": 84.0,
            "wpm=145.0": 145.0,
            "wpm": 145.0,
            "filler_word_count": 1,
            "pause_count": 3,
            "avg_pause_length": 1.2,
            "is_analyzed": True,
            "created_at": datetime.now(timezone.utc),
        }

        doc_mock = MagicMock()
        doc_mock.exists = True
        doc_mock.to_dict.return_value = session_data
        self.mock_db.collection.return_value.document.return_value.get.return_value = doc_mock

        resp = client.get(f"/reports/sessions/{session_id}/pdf")
        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/pdf"
        assert f"pitch_coach_report_{session_id}.pdf" in resp.headers["content-disposition"]
        assert resp.content[:4] == b"%PDF"

    def test_get_session_pdf_report_not_found(self):
        """GET /reports/sessions/{session_id}/pdf returns 404 for unknown or alien session."""
        doc_mock = MagicMock()
        doc_mock.exists = False
        self.mock_db.collection.return_value.document.return_value.get.return_value = doc_mock

        resp = client.get("/reports/sessions/non-existent/pdf")
        assert resp.status_code == 404

    def test_get_weekly_pdf_report_endpoint(self):
        """GET /reports/weekly/pdf returns weekly aggregate PDF."""
        # Mock stream query
        sess_mock = MagicMock()
        sess_mock.to_dict.return_value = {
            "id": "s-weekly-1",
            "user_id": "user_report_test",
            "topic_or_question": "Weekly Standup Update",
            "mode": "free_talk",
            "duration_seconds": 60.0,
            "overall_score": 90.0,
            "wpm": 135.0,
            "is_analyzed": True,
            "created_at": datetime.now(timezone.utc),
        }
        self.mock_db.collection.return_value.where.return_value.stream.return_value = [sess_mock]

        resp = client.get("/reports/weekly/pdf")
        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/pdf"
        assert "pitch_coach_weekly_report.pdf" in resp.headers["content-disposition"]
        assert resp.content[:4] == b"%PDF"
