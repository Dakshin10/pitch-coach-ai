"""
Pitch Coach AI Pipeline — backend/sessions/pipeline.py
=======================================================

This module is intentionally framework-free so it can be tested with a single
audio file without running the web server.

Pipeline steps:
  1. Transcription  — Groq Whisper API (word-level timestamps)
  2. Deterministic  — WPM, filler-word detection, pause detection
  3. Scoring        — Documented formulas, no LLM involvement
  4. LLM feedback   — Groq llama-3.1-70b-versatile → structured JSON suggestions
  5. Return         — SessionAnalysis dataclass

Usage:
    from sessions.pipeline import analyze_audio
    result = analyze_audio("recording.m4a", 180.0, {"feedback_style": "Encouraging & Constructive"}, GROQ_API_KEY)
"""

import json
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

from groq import Groq


# ─────────────────────────────────────────────────────────────────────────────
# Configurable lists and weights (tune to change the product "personality")
# ─────────────────────────────────────────────────────────────────────────────

# Single-word fillers
_FILLER_SINGLE = {
    "um", "uh", "like", "actually", "basically", "so",
    "right", "literally", "well", "okay",
}

# Multi-word fillers matched as bigrams in the transcript
_FILLER_MULTI = {
    "you know", "i mean", "kind of", "sort of",
}

# All fillers for display / breakdown
FILLER_WORDS: set = _FILLER_SINGLE | _FILLER_MULTI

# ── Clarity score weights ────────────────────────────────────────────────────
# Deducted per 1% of filler-word rate (fillers / total_words * 100).
# E.g. 10 fillers in 100 words = 10% rate → -30 clarity points.
FILLER_PENALTY_PER_RATE_UNIT: float = 3.0

# Pauses longer than this threshold (seconds) attract a penalty.
PAUSE_IDEAL_MAX_S: float = 1.5
# Penalty points per second above the threshold.
PAUSE_PENALTY_PER_EXTRA_S: float = 10.0

# ── Confidence score weights ─────────────────────────────────────────────────
# Ideal speaking rate. Deviation beyond ±WPM_TOLERANCE is penalised.
IDEAL_WPM: float = 140.0
WPM_TOLERANCE: float = 20.0           # 120–160 WPM → no penalty
WPM_PENALTY_PER_WPM: float = 0.8      # penalty per WPM of deviation outside tolerance

CONFIDENCE_CLARITY_W: float = 0.50
CONFIDENCE_WPM_W: float = 0.30
CONFIDENCE_ENERGY_W: float = 0.20    # energy_bonus is a placeholder (75) in v1

# ── Overall score weights ────────────────────────────────────────────────────
OVERALL_CONFIDENCE_W: float = 0.40
OVERALL_CLARITY_W: float = 0.40
OVERALL_STRUCTURE_W: float = 0.20    # structure_bonus is a placeholder (70) in v1

# ── Groq model names ─────────────────────────────────────────────────────────
WHISPER_MODEL: str = "whisper-large-v3"          # supports word-level timestamps
LLM_MODEL: str = "llama-3.1-70b-versatile"


# ─────────────────────────────────────────────────────────────────────────────
# Data classes
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class WordTimestamp:
    word: str
    start: float
    end: float


@dataclass
class FillerAnalysis:
    total_count: int
    breakdown: Dict[str, int]          # {"um": 4, "like": 2}
    rate_per_100_words: float          # fillers per 100 spoken words


@dataclass
class PauseAnalysis:
    count: int
    avg_length: float
    total_pause_time: float


@dataclass
class FeedbackItem:
    category: str                      # filler_words / pacing / clarity / structure / confidence
    message: str
    severity: str                      # tip / warning / positive
    example: Optional[str] = None


@dataclass
class SessionAnalysis:
    transcript: str
    word_timestamps: List[WordTimestamp]
    wpm: float
    filler: FillerAnalysis
    pauses: PauseAnalysis
    clarity_score: float
    confidence_score: float
    overall_score: float
    ai_feedback: List[FeedbackItem]
    duration_seconds: float


# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Transcription
# ─────────────────────────────────────────────────────────────────────────────

def _transcribe(audio_path: str, client: Groq) -> Tuple[str, List[WordTimestamp]]:
    """
    Call Groq Whisper with word-level timestamps.

    Falls back to segment-level timestamps gracefully if word-level is unavailable
    (e.g. very short clips).
    """
    with open(audio_path, "rb") as f:
        response = client.audio.transcriptions.create(
            file=(audio_path.split("/")[-1].split("\\")[-1], f),
            model=WHISPER_MODEL,
            response_format="verbose_json",
            timestamp_granularities=["word"],
        )

    transcript: str = response.text or ""
    word_timestamps: List[WordTimestamp] = []

    # Prefer word-level timestamps
    words = getattr(response, "words", None)
    if words:
        for w in words:
            clean = (w.word or "").strip()
            if clean:
                word_timestamps.append(WordTimestamp(
                    word=clean.lower(),
                    start=float(w.start),
                    end=float(w.end),
                ))
    else:
        # Fallback: split the transcript text and assign evenly across duration
        tokens = [t for t in transcript.lower().split() if t]
        if tokens:
            segs = getattr(response, "segments", None) or []
            if segs:
                # Use segment boundaries proportionally
                for seg in segs:
                    seg_words = seg.get("text", "").lower().split()
                    n = len(seg_words)
                    if n == 0:
                        continue
                    seg_dur = (float(seg.get("end", 0)) - float(seg.get("start", 0))) / n
                    for i, w in enumerate(seg_words):
                        t0 = float(seg.get("start", 0)) + i * seg_dur
                        word_timestamps.append(WordTimestamp(w.strip(), t0, t0 + seg_dur))

    return transcript, word_timestamps


# ─────────────────────────────────────────────────────────────────────────────
# Step 2a — Filler word detection
# ─────────────────────────────────────────────────────────────────────────────

def _compute_filler_words(word_timestamps: List[WordTimestamp]) -> FillerAnalysis:
    """
    Count filler words using FILLER_WORDS.

    Multi-word fillers (bigrams) are matched on consecutive word pairs.
    Single-word fillers are stripped of leading/trailing punctuation before matching.
    """
    if not word_timestamps:
        return FillerAnalysis(total_count=0, breakdown={}, rate_per_100_words=0.0)

    clean_words = [
        wt.word.strip(".,!?;:'\"()[]").lower()
        for wt in word_timestamps
    ]
    total_words = len(clean_words)
    breakdown: Dict[str, int] = {}

    # Single-word fillers
    for w in clean_words:
        if w in _FILLER_SINGLE:
            breakdown[w] = breakdown.get(w, 0) + 1

    # Multi-word fillers (check consecutive pairs)
    text_joined = " ".join(clean_words)
    for phrase in _FILLER_MULTI:
        count = text_joined.count(phrase)
        if count:
            breakdown[phrase] = breakdown.get(phrase, 0) + count

    total_count = sum(breakdown.values())
    rate = (total_count / max(total_words, 1)) * 100.0

    return FillerAnalysis(
        total_count=total_count,
        breakdown=breakdown,
        rate_per_100_words=round(rate, 2),
    )


# ─────────────────────────────────────────────────────────────────────────────
# Step 2b — Pause detection
# ─────────────────────────────────────────────────────────────────────────────

def _compute_pauses(
    word_timestamps: List[WordTimestamp],
    silence_threshold: float = 0.8,
) -> PauseAnalysis:
    """
    Detect pauses as gaps between consecutive word end/start pairs > threshold.

    The 0.8 s default threshold ignores natural micro-pauses between words.
    """
    if len(word_timestamps) < 2:
        return PauseAnalysis(count=0, avg_length=0.0, total_pause_time=0.0)

    gaps = []
    for i in range(1, len(word_timestamps)):
        gap = word_timestamps[i].start - word_timestamps[i - 1].end
        if gap >= silence_threshold:
            gaps.append(gap)

    if not gaps:
        return PauseAnalysis(count=0, avg_length=0.0, total_pause_time=0.0)

    return PauseAnalysis(
        count=len(gaps),
        avg_length=round(sum(gaps) / len(gaps), 2),
        total_pause_time=round(sum(gaps), 2),
    )


# ─────────────────────────────────────────────────────────────────────────────
# Step 2c — Words per minute
# ─────────────────────────────────────────────────────────────────────────────

def _compute_wpm(word_timestamps: List[WordTimestamp], duration_seconds: float) -> float:
    if not word_timestamps or duration_seconds <= 0:
        return 0.0
    minutes = duration_seconds / 60.0
    return round(len(word_timestamps) / minutes, 1)


# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Scoring formulas (deterministic, no LLM)
# ─────────────────────────────────────────────────────────────────────────────

def _compute_clarity_score(filler: FillerAnalysis, pauses: PauseAnalysis) -> float:
    """
    clarity = 100
              - (filler_rate * FILLER_PENALTY_PER_RATE_UNIT)
              - max(0, (avg_pause_length - PAUSE_IDEAL_MAX_S) * PAUSE_PENALTY_PER_EXTRA_S)
    clamped to [0, 100]
    """
    filler_ded = filler.rate_per_100_words * FILLER_PENALTY_PER_RATE_UNIT
    pause_ded = max(0.0, (pauses.avg_pause_length - PAUSE_IDEAL_MAX_S) * PAUSE_PENALTY_PER_EXTRA_S)
    return round(max(0.0, min(100.0, 100.0 - filler_ded - pause_ded)), 1)


def _compute_wpm_score(wpm: float) -> float:
    """Map WPM to a 0-100 score, with penalty only outside [IDEAL_WPM ± WPM_TOLERANCE]."""
    deviation = max(0.0, abs(wpm - IDEAL_WPM) - WPM_TOLERANCE)
    return round(max(0.0, min(100.0, 100.0 - deviation * WPM_PENALTY_PER_WPM)), 1)


def _compute_confidence_score(clarity: float, wpm: float) -> float:
    """
    confidence = clarity * 0.50 + wpm_score * 0.30 + energy_bonus * 0.20
    energy_bonus = 75 (placeholder; v2 will use librosa pitch/energy analysis)
    """
    wpm_score = _compute_wpm_score(wpm)
    energy_bonus = 75.0  # TODO v2: replace with librosa-based vocal energy signal
    raw = (
        CONFIDENCE_CLARITY_W * clarity
        + CONFIDENCE_WPM_W * wpm_score
        + CONFIDENCE_ENERGY_W * energy_bonus
    )
    return round(max(0.0, min(100.0, raw)), 1)


def _compute_overall_score(confidence: float, clarity: float) -> float:
    """
    overall = confidence * 0.40 + clarity * 0.40 + structure_bonus * 0.20
    structure_bonus = 70 (placeholder; v2 will use LLM-assessed structure quality)
    """
    structure_bonus = 70.0  # TODO v2: derive from LLM structure quality rating
    raw = (
        OVERALL_CONFIDENCE_W * confidence
        + OVERALL_CLARITY_W * clarity
        + OVERALL_STRUCTURE_W * structure_bonus
    )
    return round(max(0.0, min(100.0, raw)), 1)


# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — LLM qualitative feedback (Groq)
# ─────────────────────────────────────────────────────────────────────────────

_FALLBACK_FEEDBACK = [
    FeedbackItem(
        category="clarity",
        message="Keep practicing — consistency is the fastest path to improvement.",
        severity="tip",
    ),
]


def _get_qualitative_feedback(
    transcript: str,
    wpm: float,
    filler: FillerAnalysis,
    pauses: PauseAnalysis,
    clarity: float,
    confidence: float,
    feedback_style: str,
    client: Groq,
) -> List[FeedbackItem]:
    """
    Call Groq LLaMA to generate 3 short actionable improvement suggestions.
    Returns _FALLBACK_FEEDBACK on any error so the app always shows something.
    """
    filler_summary = dict(list(filler.breakdown.items())[:6]) if filler.breakdown else {}

    prompt = f"""You are a professional speaking coach. Analyse this speech transcript and \
the accompanying metrics, then produce exactly 3 short, specific, actionable improvement tips.

TRANSCRIPT (first 1500 chars):
{transcript[:1500]}

METRICS:
- Speaking rate: {wpm:.0f} WPM  (ideal: 130–160 WPM)
- Filler words: {filler.total_count} total ({filler.rate_per_100_words:.1f} per 100 words)
- Top fillers: {filler_summary}
- Pauses detected: {pauses.count}, avg length: {pauses.avg_length:.1f}s
- Clarity score: {clarity:.0f}/100
- Confidence score: {confidence:.0f}/100

COACHING STYLE: {feedback_style}

Return a JSON object with key "feedback" whose value is an array of exactly 3 items.
Each item must have:
  "category": one of [filler_words, pacing, clarity, structure, confidence]
  "message": one concise sentence (≤ 20 words) — the actionable tip
  "severity": one of [positive, warning, tip]
  "example": a short quoted phrase from their transcript where relevant, else null

Example:
{{
  "feedback": [
    {{"category": "filler_words", "message": "Replace 'um' with a deliberate pause for stronger impact.", "severity": "warning", "example": "...um I think the key..."}},
    {{"category": "pacing", "message": "Your pace is excellent — keep this rhythm throughout.", "severity": "positive", "example": null}},
    {{"category": "structure", "message": "Lead with your main point, then explain the reasoning.", "severity": "tip", "example": null}}
  ]
}}"""

    try:
        resp = client.chat.completions.create(
            model=LLM_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=700,
            response_format={"type": "json_object"},
        )
        raw = resp.choices[0].message.content or "{}"
        data = json.loads(raw)
        items = data.get("feedback", [])
        if not isinstance(items, list):
            return _FALLBACK_FEEDBACK

        result = []
        for item in items[:3]:
            if not isinstance(item, dict):
                continue
            result.append(FeedbackItem(
                category=str(item.get("category", "clarity")),
                message=str(item.get("message", "")),
                severity=str(item.get("severity", "tip")),
                example=item.get("example") or None,
            ))
        return result if result else _FALLBACK_FEEDBACK

    except Exception as exc:
        print(f"[pipeline] LLM feedback error: {exc}")
        return _FALLBACK_FEEDBACK


# ─────────────────────────────────────────────────────────────────────────────
# Public entry point
# ─────────────────────────────────────────────────────────────────────────────

def analyze_audio(
    audio_path: str,
    duration_seconds: float,
    user_profile: dict,
    groq_api_key: str,
) -> SessionAnalysis:
    """
    Run the full 5-step AI pipeline on a recorded audio file.

    Args:
        audio_path:        Path to the saved audio file (.m4a / .wav / .webm)
        duration_seconds:  Actual recording duration (from the Flutter timer)
        user_profile:      Dict with at least 'feedback_style'
        groq_api_key:      Groq API key

    Returns:
        SessionAnalysis — all computed metrics + LLM feedback
    """
    client = Groq(api_key=groq_api_key)
    feedback_style = user_profile.get("feedback_style", "Encouraging & Constructive")

    # Step 1
    transcript, word_timestamps = _transcribe(audio_path, client)

    # Step 2
    filler = _compute_filler_words(word_timestamps)
    pauses = _compute_pauses(word_timestamps)
    wpm = _compute_wpm(word_timestamps, duration_seconds)

    # Step 3
    clarity = _compute_clarity_score(filler, pauses)
    confidence = _compute_confidence_score(clarity, wpm)
    overall = _compute_overall_score(confidence, clarity)

    # Step 4
    ai_feedback = _get_qualitative_feedback(
        transcript, wpm, filler, pauses, clarity, confidence, feedback_style, client
    )

    return SessionAnalysis(
        transcript=transcript,
        word_timestamps=word_timestamps,
        wpm=wpm,
        filler=filler,
        pauses=pauses,
        clarity_score=clarity,
        confidence_score=confidence,
        overall_score=overall,
        ai_feedback=ai_feedback,
        duration_seconds=duration_seconds,
    )
