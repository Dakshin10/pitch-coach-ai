"""
Tests for Feature 3: Resume / JD-driven interview questions.
Verifies:
1. PyMuPDF sorted block text extraction for single-column and multi-column PDFs.
2. Graceful error for scanned PDFs with no extractable text.
3. Rigorous PII sanitization (emails, phone numbers, addresses redacted).
4. FastAPI /resume/generate-questions endpoint response and structure.
"""
import io
import unittest
from unittest.mock import MagicMock, patch
import pymupdf
from fastapi.testclient import TestClient

from main import app
from resume.sanitizer import extract_resume_text, is_scanned_pdf, sanitize_pii
from resume.pipeline import generate_resume_questions, ResumeInterviewQuestions


def _create_test_pdf(pages_text: list[list[tuple[str, tuple[float, float, float, float]]]]) -> bytes:
    """Helper to create a PDF with custom text blocks at specific rectangles."""
    doc = pymupdf.open()
    for blocks in pages_text:
        page = doc.new_page(width=600, height=800)
        for text, rect in blocks:
            page.insert_textbox(pymupdf.Rect(*rect), text)
    data = doc.tobytes()
    doc.close()
    return data


class TestResumeSanitizationAndExtraction(unittest.TestCase):
    def test_pii_redaction_email_phone_address(self):
        sample = """
        John Doe
        Email: john.doe@example.com, alt: j_doe99@university.edu
        Phone: +1 (555) 234-5678, mobile: 9876543210
        Address: 123 Elm Street, Apt 4B, Springfield, IL 62701
        Secondary: 42 Baker Street, London NW1 6XE, Bangalore 560103

        Experience:
        Built a high-throughput microservices pipeline in Go and Rust from 2021 to 2024.
        Reduced API latency by 45% using Redis caching and PostgreSQL partitioning.
        """

        sanitized = sanitize_pii(sample)

        # 1. Assert contact information is redacted
        self.assertNotIn("john.doe@example.com", sanitized)
        self.assertNotIn("j_doe99@university.edu", sanitized)
        self.assertNotIn("555) 234-5678", sanitized)
        self.assertNotIn("9876543210", sanitized)
        self.assertNotIn("123 Elm Street", sanitized)
        self.assertNotIn("62701", sanitized)
        self.assertNotIn("42 Baker Street", sanitized)

        # 2. Assert redaction markers are present
        self.assertIn("[EMAIL REDACTED]", sanitized)
        self.assertIn("[PHONE REDACTED]", sanitized)
        self.assertIn("[ADDRESS REDACTED]", sanitized)

        # 3. Assert project & technical details are preserved intact
        self.assertIn("microservices pipeline in Go and Rust", sanitized)
        self.assertIn("Reduced API latency by 45%", sanitized)
        self.assertIn("Redis caching and PostgreSQL partitioning", sanitized)
        self.assertIn("2021", sanitized)
        self.assertIn("2024", sanitized)

    def test_single_column_pdf_extraction(self):
        pdf_bytes = _create_test_pdf([
            [
                ("John Doe\nSoftware Engineer", (50, 50, 500, 100)),
                ("Projects:\n- Distributed Task Queue in Python", (50, 120, 500, 250)),
                ("Skills:\nPython, Docker, Kubernetes, AWS", (50, 270, 500, 350)),
            ]
        ])

        extracted = extract_resume_text(pdf_bytes)
        self.assertIn("John Doe", extracted)
        self.assertIn("Distributed Task Queue in Python", extracted)
        self.assertIn("Kubernetes", extracted)
        self.assertFalse(is_scanned_pdf(extracted))

    def test_multi_column_pdf_extraction_sorted(self):
        # Two columns: Column 1 (left x: 50-280), Column 2 (right x: 310-550)
        pdf_bytes = _create_test_pdf([
            [
                ("Jane Smith\nFull-Stack Developer", (50, 40, 550, 90)),
                # Left column (Projects)
                ("Left Column Projects:\n- Scalable Realtime Chat app with WebSockets", (50, 110, 280, 400)),
                # Right column (Skills & Education)
                ("Right Column Skills:\nTypeScript, React, Flutter, Dart, SQLite", (310, 110, 550, 400)),
            ]
        ])

        extracted = extract_resume_text(pdf_bytes)
        self.assertIn("Jane Smith", extracted)
        self.assertIn("Realtime Chat app", extracted)
        self.assertIn("Flutter, Dart, SQLite", extracted)
        self.assertFalse(is_scanned_pdf(extracted))

    def test_scanned_pdf_detection(self):
        # Scanned PDF has 0 text blocks (only an empty page or pure image)
        doc = pymupdf.open()
        doc.new_page(width=600, height=800)  # Empty white page with no text
        empty_pdf = doc.tobytes()
        doc.close()

        extracted = extract_resume_text(empty_pdf)
        self.assertTrue(is_scanned_pdf(extracted))


class TestResumeQuestionsEndpoint(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_scanned_pdf_returns_clear_error(self):
        doc = pymupdf.open()
        doc.new_page(width=600, height=800)
        empty_pdf_bytes = doc.tobytes()
        doc.close()

        response = self.client.post(
            "/resume/generate-questions",
            files={"resume_file": ("scanned_resume.pdf", empty_pdf_bytes, "application/pdf")},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("Scanned PDF not supported yet", response.json()["detail"])

    def test_invalid_file_extension(self):
        response = self.client.post(
            "/resume/generate-questions",
            files={"resume_file": ("resume.docx", b"word doc content", "application/octet-stream")},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Only PDF resume files are supported", response.json()["detail"])

    @patch("resume.router.generate_resume_questions")
    def test_successful_resume_and_jd_questions_generation(self, mock_generate):
        mock_generate.return_value = ResumeInterviewQuestions(
            candidate_projects=["Cloud Analytics Dashboard", "ML Classifier"],
            candidate_skills=["Python", "FastAPI", "Flutter", "GCP"],
            behavioral_questions=[
                "Tell me about leading the Cloud Analytics project.",
                "How did you handle technical ambiguity on ML models?",
                "Describe resolving a team conflict during a sprint.",
                "What was your biggest architectural mistake and fix?",
                "How do you prioritize features under tight deadlines?",
            ],
            technical_questions=[
                "Explain the data pipeline architecture for Cloud Analytics.",
                "How do you implement concurrency in FastAPI?",
                "How does Flutter manage state across complex widget trees?",
                "What database indexing strategy did you use in PostgreSQL?",
                "How do you secure JWT auth against token hijacking?",
            ],
            sanitized_snippet="Developer Resume...",
        )

        pdf_bytes = _create_test_pdf([
            [
                ("Candidate Resume\nEmail: test@gmail.com\nPhone: 123-456-7890", (50, 50, 500, 100)),
                ("Projects:\n- Cloud Analytics Dashboard\n- ML Classifier", (50, 120, 500, 250)),
                ("Skills:\nPython, FastAPI, Flutter, GCP", (50, 260, 500, 350)),
            ]
        ])

        response = self.client.post(
            "/resume/generate-questions",
            files={"resume_file": ("my_resume.pdf", pdf_bytes, "application/pdf")},
            data={"jd_text": "Looking for a Senior Flutter & Python Engineer with cloud experience."},
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(len(data["behavioral_questions"]), 5)
        self.assertEqual(len(data["technical_questions"]), 5)
        self.assertIn("Cloud Analytics Dashboard", data["candidate_projects"])
        self.assertIn("FastAPI", data["candidate_skills"])

        # Verify that mock_generate was called with sanitized text (no email or phone)
        call_args = mock_generate.call_args[1]
        sanitized_passed = call_args["sanitized_resume_text"]
        self.assertNotIn("test@gmail.com", sanitized_passed)
        self.assertNotIn("123-456-7890", sanitized_passed)
        self.assertIn("[EMAIL REDACTED]", sanitized_passed)
        self.assertIn("[PHONE REDACTED]", sanitized_passed)


if __name__ == "__main__":
    unittest.main()
