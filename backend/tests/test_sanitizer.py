"""Unit tests for backend emoji sanitizer."""

import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from utils.sanitizer import remove_emojis, sanitize_obj


def test_remove_emojis_basic():
    # Emojis specified in user regex
    raw = "Great presentation!\U0001F680 Keep up the pace!\U0001F3AF"
    assert remove_emojis(raw) == "Great presentation! Keep up the pace!"


def test_remove_emojis_multilingual_preserved():
    # Japanese, Arabic, accented characters, punctuation should NOT be stripped
    raw = "プレゼンテーション و التقييم: Excellent work!\U0001F389"
    assert remove_emojis(raw) == "プレゼンテーション و التقييم: Excellent work!"


def test_remove_emojis_various_symbols():
    raw = "Score 85% \U0001F4CA | Mic ready \U0001F399\uFE0F | Daily streak \U0001F525"
    assert remove_emojis(raw) == "Score 85% | Mic ready | Daily streak"


def test_remove_emojis_clean_spaces():
    raw = "Hello   \U0001F31F   World"
    assert remove_emojis(raw) == "Hello World"


def test_sanitize_obj_recursive():
    payload = {
        "title": "Slide Deck Ready!\U0001F4CA",
        "feedback": [
            {"message": "Nice pauses!\U0001F44F", "severity": "positive"},
            {"message": "Avoid fillers like 'um' \u26A0\uFE0F", "severity": "warning"}
        ],
        "count": 42
    }
    cleaned = sanitize_obj(payload)
    assert cleaned["title"] == "Slide Deck Ready!"
    assert cleaned["feedback"][0]["message"] == "Nice pauses!"
    assert cleaned["feedback"][1]["message"] == "Avoid fillers like 'um'"
    assert cleaned["count"] == 42
