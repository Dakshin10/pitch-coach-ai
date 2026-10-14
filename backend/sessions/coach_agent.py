"""
Agentic speaking coach — backend/sessions/coach_agent.py
========================================================

Instead of one blind prompt, the LLM gets the headline metrics and a set of
read-only tools to investigate the recording (where the fillers are, which
pauses were longest, how pace changed over time, what was said at a given
moment). It decides which tools to call, then returns 3 evidence-based tips.

Framework-free like pipeline.py: plain data in, plain dicts out, no imports
from pipeline.py (so there is no circular dependency).

Words are passed as (word, start_seconds, end_seconds) tuples.
"""

import json
import re
from typing import Callable, Dict, List, Optional, Set, Tuple

from groq import Groq
from utils.sanitizer import sanitize_obj

Word = Tuple[str, float, float]

MAX_AGENT_STEPS = 4          # tool-calling rounds before the answer is forced
MAX_TOOL_RESULT_ITEMS = 8    # keeps tool output (and token use) small
_STRIP = ".,!?;:'\"()[]"

_SYSTEM = """You are an expert speaking coach with tools that inspect a recorded speech.
Use 1-3 tool calls to find concrete evidence (specific fillers, long pauses, pace changes)
before giving advice. Then reply with ONLY a JSON object:
{"feedback": [ {"category": one of [filler_words, pacing, clarity, structure, confidence],
                "message": one concise actionable sentence (<= 20 words),
                "severity": one of [positive, warning, tip],
                "example": a short quoted phrase from the transcript, or null } x exactly 3 ]}
Be specific, never invent quotes, and match the requested coaching style. Do not use emojis in your response."""

_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_filler_instances",
            "description": "List where filler words occurred, with timestamps and surrounding words.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_pause_details",
            "description": "List the longest pauses with start time and the words before/after.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_pacing_by_segment",
            "description": "Words-per-minute for consecutive time windows, to spot rushing or dragging.",
            "parameters": {
                "type": "object",
                "properties": {
                    "window_seconds": {"type": "integer", "description": "Window size, 10-60 (default 20)."}
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_transcript_segment",
            "description": "Return the words spoken between two timestamps (seconds).",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_seconds": {"type": "number"},
                    "end_seconds": {"type": "number"},
                },
                "required": ["start_seconds", "end_seconds"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "json",
            "description": "Submit final JSON feedback array with exactly 3 items.",
            "parameters": {
                "type": "object",
                "properties": {
                    "feedback": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {"type": "string"},
                                "message": {"type": "string"},
                                "severity": {"type": "string"},
                                "example": {"type": ["string", "null"]},
                            },
                            "required": ["category", "message", "severity"],
                        },
                    }
                },
                "required": ["feedback"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "submit_feedback",
            "description": "Submit final JSON feedback array with exactly 3 items.",
            "parameters": {
                "type": "object",
                "properties": {
                    "feedback": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {"type": "string"},
                                "message": {"type": "string"},
                                "severity": {"type": "string"},
                                "example": {"type": ["string", "null"]},
                            },
                            "required": ["category", "message", "severity"],
                        },
                    }
                },
                "required": ["feedback"],
            },
        },
    },
]


# ─────────────────────────────────────────────────────────────────────────────
# Tool implementations (read-only, operate on the session's words)
# ─────────────────────────────────────────────────────────────────────────────

def _clean(w: str) -> str:
    return w.strip(_STRIP).lower()


def _context(words: List[Word], i: int, before: int = 3, after: int = 3) -> str:
    return " ".join(w for w, _, _ in words[max(0, i - before): i + after + 1])


def _build_tools(
    words: List[Word], fillers_single: Set[str], fillers_multi: Set[str]
) -> Dict[str, Callable[..., dict]]:

    def get_filler_instances() -> dict:
        found = []
        for i, (w, start, _) in enumerate(words):
            c = _clean(w)
            nxt = _clean(words[i + 1][0]) if i + 1 < len(words) else ""
            if c in fillers_single or f"{c} {nxt}" in fillers_multi:
                found.append({"at_seconds": round(start, 1), "context": _context(words, i)})
        return {"total": len(found), "instances": found[:MAX_TOOL_RESULT_ITEMS]}

    def get_pause_details() -> dict:
        pauses = []
        for i in range(1, len(words)):
            gap = words[i][1] - words[i - 1][2]
            if gap >= 0.8:
                pauses.append({
                    "at_seconds": round(words[i - 1][2], 1),
                    "length_seconds": round(gap, 1),
                    "before": words[i - 1][0],
                    "after": words[i][0],
                })
        pauses.sort(key=lambda p: p["length_seconds"], reverse=True)
        return {"total": len(pauses), "longest": pauses[:MAX_TOOL_RESULT_ITEMS]}

    def get_pacing_by_segment(window_seconds: int = 20) -> dict:
        window = max(10, min(60, int(window_seconds or 20)))
        if not words:
            return {"segments": []}
        end = words[-1][2]
        segments, t = [], 0.0
        while t < end and len(segments) < MAX_TOOL_RESULT_ITEMS * 2:
            n = sum(1 for _, s, _ in words if t <= s < t + window)
            segments.append({"from": round(t), "to": round(min(t + window, end)),
                             "wpm": round(n * 60.0 / window)})
            t += window
        return {"window_seconds": window, "segments": segments}

    def get_transcript_segment(start_seconds: float, end_seconds: float) -> dict:
        text = " ".join(w for w, s, _ in words if start_seconds <= s <= end_seconds)
        return {"text": text[:600]}

    return {
        "get_filler_instances": get_filler_instances,
        "get_pause_details": get_pause_details,
        "get_pacing_by_segment": get_pacing_by_segment,
        "get_transcript_segment": get_transcript_segment,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Agent loop
# ─────────────────────────────────────────────────────────────────────────────

def _parse_feedback(raw: str) -> Optional[List[dict]]:
    """Extracts the feedback array from a model reply (tolerates code fences / prose)."""
    match = re.search(r"\{.*\}", raw or "", re.DOTALL)
    if not match:
        return None
    try:
        items = json.loads(match.group(0)).get("feedback")
    except (json.JSONDecodeError, AttributeError):
        return None
    if isinstance(items, list) and items:
        return sanitize_obj(items)
    return None


def run_feedback_agent(
    client: Groq,
    model: str,
    transcript: str,
    words: List[Word],
    metrics: dict,
    feedback_style: str,
    fillers_single: Set[str],
    fillers_multi: Set[str],
) -> Optional[List[dict]]:
    """
    Runs the tool-using coach. Returns a list of feedback dicts, or None if the
    agent could not produce a valid answer (caller then falls back).
    """
    tools = _build_tools(words, fillers_single, fillers_multi)
    messages: List[dict] = [
        {"role": "system", "content": _SYSTEM},
        {"role": "user", "content": (
            f"COACHING STYLE: {feedback_style}\n\n"
            f"METRICS: {json.dumps(metrics)}\n\n"
            f"TRANSCRIPT (first 1500 chars):\n{transcript[:1500]}"
        )},
    ]

    for _ in range(MAX_AGENT_STEPS):
        resp = client.chat.completions.create(
            model=model, messages=messages, tools=_TOOLS,
            tool_choice="auto", temperature=0.3, max_tokens=1500,
        )
        msg = resp.choices[0].message

        if not msg.tool_calls:
            parsed = _parse_feedback(msg.content or "")
            if parsed:
                return parsed
            break  # no tools and no usable answer → force a final answer below

        # Check if the model submitted final feedback via tool call directly
        for call in msg.tool_calls:
            if call.function.name in ("json", "submit_feedback"):
                try:
                    args = json.loads(call.function.arguments or "{}")
                    items = args.get("feedback")
                    if isinstance(items, list) and items:
                        return sanitize_obj(items)
                except Exception:
                    pass

        messages.append({
            "role": "assistant",
            "content": msg.content or "",
            "tool_calls": [
                {"id": c.id, "type": "function",
                 "function": {"name": c.function.name, "arguments": c.function.arguments}}
                for c in msg.tool_calls
            ],
        })
        for call in msg.tool_calls:
            fn = tools.get(call.function.name)
            try:
                args = json.loads(call.function.arguments or "{}")
                result = fn(**args) if fn else {"error": "unknown tool"}
            except Exception as exc:  # bad args from the model must not crash the run
                result = {"error": str(exc)}
            messages.append({
                "role": "tool", "tool_call_id": call.id,
                "content": json.dumps(result)[:3000],
            })

    # Step budget used up (or no valid answer): demand the final JSON, no tools.
    messages.append({"role": "user", "content": "Now give the final JSON feedback."})
    final = client.chat.completions.create(
        model=model, messages=messages, temperature=0.3, max_tokens=1500,
        response_format={"type": "json_object"},
    )
    return _parse_feedback(final.choices[0].message.content or "")
