"""
Emoji sanitizer utility for Pitch Coach backend.
Removes all emoji codepoints matching the project regex from strings,
dicts, and lists before responses are stored or returned.
"""

import re
from typing import Any

# Standard emoji regex pattern as required:
# [\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{1F1E6}-\u{1F1FF}]
EMOJI_PATTERN = re.compile(
    r'[\U0001F300-\U0001FAFF'
    r'\u2600-\u27BF'
    r'\u2B00-\u2BFF'
    r'\uFE0F'
    r'\u200D'
    r'\U0001F1E6-\U0001F1FF]'
)


def remove_emojis(text: str) -> str:
    """Strips all emoji characters from the provided string and trims excess whitespace."""
    if not text or not isinstance(text, str):
        return text
    cleaned = EMOJI_PATTERN.sub('', text)
    # Collapse multiple consecutive whitespace that might have surrounded the emoji
    cleaned = re.sub(r'[ \t]+', ' ', cleaned)
    # Also clean up punctuation artifacts like " ! " -> "!"
    cleaned = re.sub(r' +([!?,.:;])', r'\1', cleaned)
    return cleaned.strip()


def sanitize_obj(data: Any) -> Any:
    """Recursively sanitizes dicts, lists, and strings to eliminate any emojis."""
    if isinstance(data, str):
        return remove_emojis(data)
    elif isinstance(data, dict):
        return {k: sanitize_obj(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [sanitize_obj(item) for item in data]
    return data
