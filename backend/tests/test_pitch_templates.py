"""
Tests for Pitch Templates (Feature 5).
Verifies:
1. Data-driven template registry and REST endpoints (list, get, 404).
2. Data-entry extensibility (adding a template without code changes).
3. Structure score calculation based on template keywords and weights.
4. Template rubric altering coaching feedback and structure scores.
"""
import pytest
from unittest.mock import MagicMock, patch
from fastapi.testclient import TestClient
from main import app
from templates.registry import (
    TEMPLATE_REGISTRY,
    PitchTemplate,
    TemplateSection,
    get_template,
    list_templates,
    register_template,
)
from sessions.pipeline import (
    _compute_structure_score,
    _compute_overall_score,
    _get_qualitative_feedback,
    analyze_audio,
)
from sessions.pipeline import FillerAnalysis, PauseAnalysis

client = TestClient(app)


def test_list_templates_endpoint():
    """Verify GET /templates returns standard templates."""
    response = client.get("/templates")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    ids = [t["id"] for t in data]
    assert "investor_pitch" in ids
    assert "hackathon_demo" in ids
    assert "elevator_pitch" in ids
    assert "viva" in ids

    # Check structure of investor_pitch
    investor = next(t for t in data if t["id"] == "investor_pitch")
    assert investor["target_duration_seconds"] == 180
    assert len(investor["sections"]) == 5
    assert "the_ask" in [s["id"] for s in investor["sections"]]
    assert "the_ask" in investor["rubric"]


def test_get_template_endpoint():
    """Verify GET /templates/{id} and 404 for missing template."""
    response = client.get("/templates/elevator_pitch")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == "elevator_pitch"
    assert data["target_duration_seconds"] == 60

    bad_res = client.get("/templates/non_existent_deck")
    assert bad_res.status_code == 404
    assert "not found" in bad_res.json()["detail"].lower()


def test_extensibility_add_template_data_entry():
    """Adding a new template needs only a data entry, not code changes."""
    custom_template = PitchTemplate(
        id="sales_cold_call",
        title="B2B Cold Call",
        description="Quick outbound phone pitch to book an enterprise discovery meeting.",
        target_duration_seconds=90,
        sections=[
            TemplateSection(
                id="pattern_interrupt",
                name="Pattern Interrupt",
                description="Respectful reason for calling.",
                weight=30.0,
                keywords=["calling", "caught", "minute", "time"],
            ),
            TemplateSection(
                id="value_prop",
                name="Value Proposition",
                description="Pain point and how you solve it.",
                weight=40.0,
                keywords=["reduce", "save", "automate", "revenue"],
            ),
            TemplateSection(
                id="call_to_action",
                name="Call to Action",
                description="Ask for 15 minutes next Tuesday.",
                weight=30.0,
                keywords=["calendar", "tuesday", "brief", "schedule"],
            ),
        ],
        rubric={
            "pattern_interrupt": "Was permission obtained gracefully?",
            "value_prop": "Did it hit a quantified business outcome?",
            "call_to_action": "Was a specific time suggested?",
        },
        coaching_focus="Objection handling, low friction CTA, and crisp brevity.",
    )

    register_template(custom_template)
    try:
        assert get_template("sales_cold_call") is not None
        response = client.get("/templates/sales_cold_call")
        assert response.status_code == 200
        assert response.json()["title"] == "B2B Cold Call"
    finally:
        TEMPLATE_REGISTRY.pop("sales_cold_call", None)


def test_structure_score_investor_pitch():
    """Verify structure scoring detects covered vs missing sections."""
    # Full transcript hitting all 5 investor sections
    rich_transcript = (
        "Our customers face a critical problem with industry market costs. "
        "Our solution is an AI platform with proprietary algorithms. "
        "We have achieved strong traction with 10k users, $50k arr and 20% month over month growth. "
        "Our business model is a SaaS subscription with high gross margins. "
        "We are now raising capital with an ask of $1.5M for milestones and hiring."
    )
    score, detected, missing = _compute_structure_score(rich_transcript, "investor_pitch")
    assert score >= 90.0
    assert len(detected) == 5
    assert len(missing) == 0

    # Incomplete transcript missing traction, business model, and the ask
    poor_transcript = (
        "Hello everyone, let me talk about the problem with healthcare. "
        "We built a great product platform."
    )
    p_score, p_detected, p_missing = _compute_structure_score(poor_transcript, "investor_pitch")
    assert p_score < 60.0
    assert "The Ask & Use of Funds" in p_missing
    assert "Business Model" in p_missing


def test_overall_score_reflects_structure_score():
    """Formula: overall = 0.40 * confidence + 0.40 * clarity + 0.20 * structure_score."""
    confidence = 80.0
    clarity = 80.0
    # Perfect structure (100) -> 0.4*80 + 0.4*80 + 0.2*100 = 32 + 32 + 20 = 84.0
    score_high = _compute_overall_score(confidence, clarity, structure_score=100.0)
    assert score_high == pytest.approx(84.0, abs=0.5)

    # Poor structure (20) -> 0.4*80 + 0.4*80 + 0.2*20 = 32 + 32 + 4 = 68.0
    score_low = _compute_overall_score(confidence, clarity, structure_score=20.0)
    assert score_low == pytest.approx(68.0, abs=0.5)

    # Without template -> structure_score=None -> defaults to 70.0 -> 0.4*80 + 0.4*80 + 0.2*70 = 78.0
    score_no_template = _compute_overall_score(confidence, clarity, structure_score=None)
    assert score_no_template == pytest.approx(78.0, abs=0.5)


def test_template_coaching_feedback_differentiation():
    """Verify rubric and template context is passed to the LLM coach."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.choices = [
        MagicMock(
            message=MagicMock(
                content='{"feedback": [{"category": "structure", "message": "Remember to articulate your specific capital Ask and runaway timeline.", "severity": "tip", "example": null}]}'
            )
        )
    ]
    mock_client.chat.completions.create.return_value = mock_response

    filler = FillerAnalysis(total_count=1, breakdown={"um": 1}, rate_per_100_words=1.0)
    pauses = PauseAnalysis(count=1, avg_length=1.0, total_pause_time=1.0)

    items = _get_qualitative_feedback(
        transcript="We have a problem and a solution.",
        wpm=140.0,
        filler=filler,
        pauses=pauses,
        clarity=75.0,
        confidence=80.0,
        feedback_style="Direct & Actionable",
        client=mock_client,
        template_id="investor_pitch",
        detected_sections=["hook_problem", "solution_product"],
        missing_sections=["traction_market", "business_model", "the_ask"],
    )

    # Check LLM prompt received template info
    create_call = mock_client.chat.completions.create.call_args
    prompt_sent = create_call[1]["messages"][0]["content"]
    assert "Investor Pitch" in prompt_sent
    assert "- Sections Missing:" in prompt_sent
    assert "the_ask" in prompt_sent
    assert len(items) == 1
    assert items[0].category == "structure"
