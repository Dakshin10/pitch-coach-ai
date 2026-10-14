"""
Tests for Multi-Turn AI Interviewer (Feature 4).
Verifies:
1. Vague answers trigger a follow-up.
2. Strong answers move on without a follow-up.
3. Follow-up cap at 2 is strictly enforced.
4. Latency is measured and reported (latency_ms > 0).
5. Multi-turn exchange scoring handles all turns.
6. FastAPI endpoints return proper HTTP statuses and models.
"""
import json
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from main import app
from interviewer.pipeline import (
    evaluate_interview_turn,
    score_full_exchange,
    _heuristic_evaluate_vagueness,
)
from interviewer.schemas import (
    ScoreExchangeRequest,
    TurnEvaluateRequest,
    TurnMessage,
)

client = TestClient(app)


def test_vague_answer_triggers_follow_up():
    """A vague answer without root cause or results triggers a follow-up."""
    vague_request = TurnEvaluateRequest(
        question="Tell me about a difficult bug you encountered and resolved.",
        candidate_answer="I found a bug in production and I fixed it and deployed the code.",
        turn_history=[],
        follow_up_count=0,
    )
    result = evaluate_interview_turn(vague_request, groq_api_key=None)

    assert result.move_on is False
    assert result.follow_up is not None
    assert result.is_vague is True
    assert len(result.follow_up) > 10
    assert result.latency_ms is not None
    assert result.latency_ms >= 0


def test_strong_answer_moves_on():
    """A detailed answer with root cause, implementation specifics, and measurable metrics moves on."""
    strong_request = TurnEvaluateRequest(
        question="Tell me about a difficult bug you encountered and resolved.",
        candidate_answer=(
            "In our checkout service, we experienced P99 latency spikes up to 4.2 seconds caused by unindexed "
            "database queries during heavy loads. I diagnosed the bottleneck by analyzing query execution plans, "
            "discovered that an unindexed foreign key in the cart_items table caused full table scans, "
            "and implemented a composite B-tree index. As a direct result, P99 query latency reduced by 85% down "
            "to 140ms and server CPU utilization dropped from 88% to 22%."
        ),
        turn_history=[],
        follow_up_count=0,
    )
    result = evaluate_interview_turn(strong_request, groq_api_key=None)

    assert result.move_on is True
    assert result.follow_up is None
    assert result.is_vague is False
    assert result.latency_ms is not None


def test_follow_up_cap_enforced_at_max_two():
    """When follow_up_count reaches 2, follow-up is suppressed and move_on is forced to True."""
    capped_request = TurnEvaluateRequest(
        question="Tell me about a difficult bug you encountered and resolved.",
        candidate_answer="Still trying to fix it basically.",  # highly vague
        turn_history=[
            TurnMessage(role="interviewer", content="Can you provide specifics?"),
            TurnMessage(role="candidate", content="It was a python bug."),
        ],
        follow_up_count=2,  # Already at cap
    )
    result = evaluate_interview_turn(capped_request, groq_api_key=None)

    assert result.move_on is True
    assert result.follow_up is None
    assert "limit reached" in result.reason.lower() or "maximum" in result.reason.lower()


def test_groq_llm_evaluation_mocked():
    """Verifies LLM structured output parsing and fallback handling."""
    mock_groq_resp = MagicMock()
    mock_groq_resp.choices = [
        MagicMock(
            message=MagicMock(
                content=json.dumps({
                    "follow_up": "What specific metrics improved after your change?",
                    "move_on": False,
                    "reason": "Missing measurable performance metrics.",
                })
            )
        )
    ]

    with patch("interviewer.pipeline.Groq") as mock_groq_class:
        mock_instance = MagicMock()
        mock_instance.chat.completions.create.return_value = mock_groq_resp
        mock_groq_class.return_value = mock_instance

        req = TurnEvaluateRequest(
            question="Describe your performance optimization work.",
            candidate_answer="I made the site faster by caching stuff.",
            follow_up_count=0,
        )
        res = evaluate_interview_turn(req, groq_api_key="gsk_mock_test_key")

        assert res.move_on is False
        assert "metrics" in res.follow_up.lower()
        assert res.is_vague is True
        assert res.latency_ms > 0


def test_score_full_exchange():
    """Full multi-turn dialogue scoring calculates clarity, confidence, overall, and STAR criteria."""
    turns = [
        TurnMessage(role="interviewer", content="Tell me about a time you led a challenging migration."),
        TurnMessage(role="candidate", content="I led our PostgreSQL migration to Aurora."),
        TurnMessage(role="interviewer", content="What was the root cause of migration downtime risks and how did you mitigate it?"),
        TurnMessage(role="candidate", content="The main risk was replica lag, so we implemented CDC using Debezium and achieved zero-downtime cutover."),
    ]
    res = score_full_exchange(
        question="Tell me about a time you led a challenging migration.",
        turns=turns,
        wpm=138.0,
        filler_words_per_100=2.1,
        pause_count=1,
        groq_api_key=None,
    )

    assert 0 <= res.clarity_score <= 100
    assert 0 <= res.confidence_score <= 100
    assert 0 <= res.overall_score <= 100
    assert len(res.strengths) >= 1
    assert len(res.improvements) >= 1
    assert res.star_assessment is not None
    assert "situation" in res.star_assessment
    assert res.latency_ms is not None


def test_evaluate_turn_endpoint():
    """POST /interview/evaluate-turn responds with valid 200 and schema."""
    resp = client.post(
        "/interview/evaluate-turn",
        json={
            "question": "Explain how you handle conflicts in team code reviews.",
            "candidate_answer": "I talk to people and we resolve it.",
            "turn_history": [],
            "follow_up_count": 0,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "move_on" in data
    assert "reason" in data
    assert "latency_ms" in data


def test_score_exchange_endpoint():
    """POST /interview/score-exchange responds with valid 200 and schema."""
    resp = client.post(
        "/interview/score-exchange",
        json={
            "question": "Explain how you handle conflicts in team code reviews.",
            "turns": [
                {"role": "interviewer", "content": "Explain how you handle conflicts in team code reviews."},
                {"role": "candidate", "content": "I set up a 1-on-1 discussion, anchor on automated linter rules, and achieve alignment."},
            ],
            "wpm": 142.0,
            "filler_words_per_100": 1.5,
            "pause_count": 0,
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "clarity_score" in data
    assert "confidence_score" in data
    assert "overall_score" in data
    assert "strengths" in data
