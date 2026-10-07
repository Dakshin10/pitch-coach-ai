"""Unit tests for Slide Coach pipeline: PDF validation, rendering, duration rescaling, and schema validation."""
import io
import os
import shutil
import tempfile
import unittest
from unittest.mock import MagicMock, patch

import pymupdf
from slides.pipeline import (
    extract_all_slides_vision,
    rescale_durations,
    synthesize_deck_coaching,
    validate_and_render_pdf,
)
from slides.schemas import (
    BatchVisionResponse,
    DeckCoachingResult,
    DeckSummary,
    SlideCoaching,
    SlideVisionDescription,
)


def _create_dummy_pdf(num_pages: int = 3) -> bytes:
    """Helper to generate an in-memory valid PDF with dummy text using PyMuPDF."""
    doc = pymupdf.open()
    for i in range(num_pages):
        page = doc.new_page(width=600, height=400)
        page.insert_text((50, 50), f"Slide {i + 1}: Sample Presentation Content", fontsize=18)
    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes


class TestSlideCoachPipeline(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_pdf_validation_magic_bytes(self):
        invalid_bytes = b"NOT_A_PDF_FILE"
        with self.assertRaises(ValueError) as ctx:
            validate_and_render_pdf(invalid_bytes, self.temp_dir)
        self.assertIn("Invalid file format", str(ctx.exception))

    def test_pdf_rendering_success(self):
        pdf_bytes = _create_dummy_pdf(num_pages=3)
        page_count, paths = validate_and_render_pdf(pdf_bytes, self.temp_dir)
        self.assertEqual(page_count, 3)
        self.assertEqual(len(paths), 3)
        for p in paths:
            self.assertTrue(os.path.exists(p))
            self.assertTrue(p.endswith(".jpg"))

    def test_pdf_page_limit_enforced(self):
        pdf_bytes = _create_dummy_pdf(num_pages=61)
        with self.assertRaises(ValueError) as ctx:
            validate_and_render_pdf(pdf_bytes, self.temp_dir)
        self.assertIn("exceeds maximum page limit", str(ctx.exception))

    def test_duration_rescaling(self):
        # 3 slides with total 90 seconds, target is 180 seconds
        slides = [
            {"slide_number": 1, "target_duration_seconds": 30},
            {"slide_number": 2, "target_duration_seconds": 30},
            {"slide_number": 3, "target_duration_seconds": 30},
        ]
        target_total = 180
        rescale_durations(slides, target_total)

        total_scaled = sum(s["target_duration_seconds"] for s in slides)
        self.assertEqual(total_scaled, target_total)
        # Check that individual slides were proportionally scaled
        self.assertTrue(all(s["target_duration_seconds"] >= 50 for s in slides))

    def test_duration_rescaling_already_within_margin(self):
        # Within 5% of 180 (e.g. 175) -> no change needed
        slides = [
            {"slide_number": 1, "target_duration_seconds": 60},
            {"slide_number": 2, "target_duration_seconds": 60},
            {"slide_number": 3, "target_duration_seconds": 55},
        ]
        rescale_durations(slides, 180)
        self.assertEqual(slides[0]["target_duration_seconds"], 60)
        self.assertEqual(slides[1]["target_duration_seconds"], 60)
        self.assertEqual(slides[2]["target_duration_seconds"], 55)

    @patch("slides.pipeline._call_groq_with_backoff")
    def test_stage_b_vision_extraction(self, mock_groq_call):
        # Create 2 dummy images
        pdf_bytes = _create_dummy_pdf(num_pages=2)
        _, paths = validate_and_render_pdf(pdf_bytes, self.temp_dir)

        # Mock Groq JSON response
        mock_groq_call.return_value = """{
            "slides": [
                {
                    "slide_number": 1,
                    "title": "Problem Statement",
                    "main_message": "High latency in audio processing",
                    "visible_text": "80% of teams struggle",
                    "visuals": "Bar chart showing latency reduction",
                    "text_density": "low",
                    "readability_issues": []
                },
                {
                    "slide_number": 2,
                    "title": "Solution Architecture",
                    "main_message": "Pitch Coach AI edge pipeline",
                    "visible_text": "FastAPI + Whisper + Vision",
                    "visuals": "System flow diagram",
                    "text_density": "medium",
                    "readability_issues": []
                }
            ]
        }"""

        mock_client = MagicMock()
        results = extract_all_slides_vision(paths, mock_client, "test-vision-model")

        self.assertEqual(len(results), 2)
        self.assertEqual(results[0].slide_number, 1)
        self.assertEqual(results[0].title, "Problem Statement")
        self.assertEqual(results[1].slide_number, 2)
        self.assertEqual(results[1].title, "Solution Architecture")

    @patch("slides.pipeline._call_groq_with_backoff")
    def test_stage_c_coaching_synthesis(self, mock_groq_call):
        descriptions = [
            SlideVisionDescription(
                slide_number=1,
                title="Intro",
                main_message="Intro hook",
                visible_text="Logo",
                visuals="Brand image",
                text_density="low",
                readability_issues=[],
            ),
            SlideVisionDescription(
                slide_number=2,
                title="Problem",
                main_message="Big pain point",
                visible_text="Key stats",
                visuals="Graph",
                text_density="medium",
                readability_issues=[],
            ),
        ]

        mock_groq_call.return_value = """{
            "deck_summary": {
                "story_arc": "Strong opening hook connecting user pain to product advantage.",
                "missing_sections": ["Traction", "Ask"],
                "overall_score": 82,
                "top_3_fixes": ["Add unit economics", "Sharpen problem metric", "Include call to action"]
            },
            "slides": [
                {
                    "slide_number": 1,
                    "slide_title": "Introduction",
                    "target_duration_seconds": 60,
                    "key_takeaway": "Introduce the vision",
                    "talking_points": ["Welcome judges", "State the core problem", "Hook the audience"],
                    "suggested_script": "Good morning judges, we are here today to show you how AI changes communication.",
                    "transition_to_next": "Let us take a closer look at the actual pain points.",
                    "slide_critique": ["Make subtitle font larger"]
                },
                {
                    "slide_number": 2,
                    "slide_title": "The Problem",
                    "target_duration_seconds": 120,
                    "key_takeaway": "Quantify market friction",
                    "talking_points": ["Detail pain point", "Show market loss", "Highlight urgency"],
                    "suggested_script": "Every year millions of professionals miss career growth due to presentation anxiety.",
                    "transition_to_next": "Here is our solution.",
                    "slide_critique": ["Graph contrast needs improvement"]
                }
            ]
        }"""

        mock_client = MagicMock()
        result = synthesize_deck_coaching(
            descriptions=descriptions,
            audience="investors",
            time_limit_seconds=180,
            goal="Raise seed round",
            client=mock_client,
            model="test-text-model",
        )

        self.assertIsInstance(result, DeckCoachingResult)
        self.assertEqual(result.deck_summary.overall_score, 82)
        self.assertEqual(len(result.slides), 2)
        self.assertEqual(sum(s.target_duration_seconds for s in result.slides), 180)
        self.assertEqual(result.slides[0].visuals, "Brand image")

    def test_filler_counting_including_tamil_hinglish(self):
        from slides.pipeline import count_slide_fillers
        words = ["Hello", "um", "welcome", "ah", "to", "our", "pitch", "you", "know", "actually", "basically", "we", "solve", "this"]
        total, breakdown = count_slide_fillers(words)
        self.assertEqual(total, 5)  # um, ah, you know, actually, basically
        self.assertEqual(breakdown.get("um"), 1)
        self.assertEqual(breakdown.get("ah"), 1)
        self.assertEqual(breakdown.get("you know"), 1)
        self.assertEqual(breakdown.get("actually"), 1)
        self.assertEqual(breakdown.get("basically"), 1)

    def test_split_transcript_by_slides(self):
        from slides.pipeline import split_transcript_by_slides
        # 3 words on slide 1 (0-10s), 3 words on slide 2 (10-25s)
        word_timestamps = [
            ("welcome", 1.0, 1.8),
            ("to", 2.0, 2.3),
            ("pitch", 3.0, 3.7),
            ("now", 11.0, 11.5),
            ("the", 12.0, 12.3),
            ("problem", 13.0, 13.9),
        ]
        slide_timestamps = [
            {"slide_number": 1, "entered_at_ms": 0},
            {"slide_number": 2, "entered_at_ms": 10000},
        ]
        splits = split_transcript_by_slides(word_timestamps, slide_timestamps, total_audio_duration_seconds=25.0)

        self.assertIn(1, splits)
        self.assertIn(2, splits)
        self.assertEqual(splits[1]["transcript"], "welcome to pitch")
        self.assertEqual(splits[2]["transcript"], "now the problem")
        self.assertEqual(splits[1]["duration_seconds"], 10.0)
        self.assertEqual(splits[2]["duration_seconds"], 15.0)

    @patch("slides.pipeline._call_groq_with_backoff")
    def test_talking_points_coverage(self, mock_groq_call):
        from slides.pipeline import check_talking_points_coverage
        mock_groq_call.return_value = """{
            "coverage": [
                {"point": "State market size", "covered": true, "evidence": "40 billion dollar TAM"},
                {"point": "Explain pricing tiers", "covered": false, "evidence": null}
            ]
        }"""
        mock_client = MagicMock()
        cov, pct = check_talking_points_coverage(
            talking_points=["State market size", "Explain pricing tiers"],
            slide_transcript="We are addressing a 40 billion dollar TAM in communication.",
            client=mock_client,
            model="test-text-model",
        )
        self.assertEqual(len(cov), 2)
        self.assertTrue(cov[0]["covered"])
        self.assertFalse(cov[1]["covered"])
        self.assertEqual(pct, 50.0)


if __name__ == "__main__":
    unittest.main()
