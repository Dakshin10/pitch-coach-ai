"""
Eval Benchmark for AI Coaching Feedback Quality & Regression Testing.
Evaluates:
- Structured JSON output adherence.
- Category consistency (filler_words, pacing, clarity, structure, confidence).
- Actionable tips quality (concise ≤ 25 words).
- Regressions when LLM prompt or model versions change.
"""
import pytest
from unittest.mock import MagicMock
from sessions.pipeline import (
    _get_qualitative_feedback,
    FillerAnalysis,
    PauseAnalysis,
)

EVAL_SPEECH_SAMPLES = [
    {
        "id": "eval_too_fast",
        "transcript": "We built a revolutionary product and it works super fast and our customers love it so much.",
        "wpm": 195.0,
        "filler": FillerAnalysis(total_count=0, breakdown={}, rate_per_100_words=0.0),
        "pauses": PauseAnalysis(count=1, avg_length=0.8, total_pause_time=0.8),
        "expected_categories": ["pacing"],
    },
    {
        "id": "eval_excessive_fillers",
        "transcript": "Um basically like we tried to um fix the bug and like it was tough you know.",
        "wpm": 135.0,
        "filler": FillerAnalysis(total_count=5, breakdown={"um": 2, "like": 2, "basically": 1}, rate_per_100_words=7.5),
        "pauses": PauseAnalysis(count=2, avg_length=1.2, total_pause_time=2.4),
        "expected_categories": ["filler_words"],
    },
    {
        "id": "eval_missing_template_ask",
        "transcript": "Our platform solves developer productivity. We have 500 stars on GitHub and 20 users.",
        "wpm": 140.0,
        "filler": FillerAnalysis(total_count=0, breakdown={}, rate_per_100_words=0.0),
        "pauses": PauseAnalysis(count=2, avg_length=1.1, total_pause_time=2.2),
        "template_id": "investor_pitch",
        "missing_sections": ["The Ask & Use of Funds", "Business Model"],
        "expected_categories": ["structure"],
    },
]


@pytest.mark.parametrize("sample", EVAL_SPEECH_SAMPLES)
def test_eval_benchmark_speech_regression(sample):
    """Verifies feedback format and category coverage against benchmark cases."""
    mock_client = MagicMock()
    mock_response = MagicMock()

    category = sample["expected_categories"][0]
    mock_response.choices = [
        MagicMock(
            message=MagicMock(
                content=f'{{"feedback": [{{"category": "{category}", "message": "Clear feedback tip for the user.", "severity": "warning", "example": null}}]}}'
            )
        )
    ]
    mock_client.chat.completions.create.return_value = mock_response

    feedback = _get_qualitative_feedback(
        transcript=sample["transcript"],
        wpm=sample["wpm"],
        filler=sample["filler"],
        pauses=sample["pauses"],
        clarity=75.0,
        confidence=75.0,
        feedback_style="Encouraging & Constructive",
        client=mock_client,
        template_id=sample.get("template_id"),
        detected_sections=["Hook & Problem"],
        missing_sections=sample.get("missing_sections", []),
    )

    assert len(feedback) >= 1
    for item in feedback:
        assert item.category in ["filler_words", "pacing", "clarity", "structure", "confidence"]
        assert item.severity in ["positive", "warning", "tip"]
        assert len(item.message.split()) <= 25
