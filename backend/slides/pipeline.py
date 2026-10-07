"""Slide Coach Three-Stage Pipeline: Render -> Vision Extraction -> Coaching Synthesis."""
import asyncio
import base64
import json
import logging
import math
import os
import re
import time
from typing import Any, Dict, List, Optional, Tuple

import pymupdf  # PyMuPDF
from groq import Groq
from pydantic import ValidationError

from config import get_settings
from slides.schemas import (
    BatchVisionResponse,
    DeckCoachingResult,
    DeckSummary,
    SlideCoaching,
    SlideVisionDescription,
)

logger = logging.getLogger(__name__)

# Max images allowed per request by Groq Vision
GROQ_MAX_VISION_BATCH = 5
# Concurrent batch semaphore to respect rate limits
VISION_SEMAPHORE_LIMIT = 2
# Max retries for API calls
MAX_API_RETRIES = 3


# ─────────────────────────────────────────────────────────────────────────────
# Stage A: Render (PDF -> High-Res JPEGs)
# ─────────────────────────────────────────────────────────────────────────────

def validate_and_render_pdf(
    pdf_bytes: bytes,
    output_dir: str,
    max_width: int = 1024,
    jpeg_quality: int = 70,
) -> Tuple[int, List[str]]:
    """
    Validates PDF magic bytes, length (1-30 pages), and renders each page to JPEG.
    Returns: (page_count, list_of_image_file_paths)
    """
    start_time = time.time()

    # 1. Validate magic bytes
    if not pdf_bytes.startswith(b"%PDF"):
        raise ValueError("Invalid file format. The file is not a valid PDF.")

    # 2. Open document with PyMuPDF
    doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    page_count = len(doc)

    if page_count < 1:
        doc.close()
        raise ValueError("The PDF document is empty (0 pages).")
    if page_count > 30:
        doc.close()
        raise ValueError(f"Deck exceeds maximum page limit (found {page_count} pages, limit is 30).")

    os.makedirs(output_dir, exist_ok=True)
    image_paths: List[str] = []

    for i in range(page_count):
        page = doc.load_page(i)
        rect = page.rect
        # Scale to max_width preserving aspect ratio
        zoom = max_width / rect.width if rect.width > max_width else 1.0
        mat = pymupdf.Matrix(zoom, zoom)
        pix = page.get_pixmap(matrix=mat, alpha=False)

        image_path = os.path.join(output_dir, f"slide_{i + 1}.jpg")
        # Save as JPEG with requested quality
        pix.save(image_path, jpg_quality=jpeg_quality)
        image_paths.append(image_path)

    doc.close()
    elapsed = time.time() - start_time
    logger.info("Stage A (Render): rendered %d slides in %.2fs to %s", page_count, elapsed, output_dir)
    return page_count, image_paths


# ─────────────────────────────────────────────────────────────────────────────
# Stage B: Vision Extraction (Batches of <= 5 images)
# ─────────────────────────────────────────────────────────────────────────────

def _encode_image_b64(image_path: str) -> str:
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def _call_groq_with_backoff(
    client: Groq,
    model: str,
    messages: List[Dict[str, Any]],
    response_format: Optional[Dict[str, str]] = None,
    max_retries: int = MAX_API_RETRIES,
) -> str:
    """Invokes Groq API with exponential backoff on 429 / 5xx."""
    last_err = None
    for attempt in range(max_retries):
        try:
            kwargs: Dict[str, Any] = {
                "model": model,
                "messages": messages,
                "temperature": 0.2,
            }
            if response_format:
                kwargs["response_format"] = response_format
            resp = client.chat.completions.create(**kwargs)
            return resp.choices[0].message.content or ""
        except Exception as e:
            last_err = e
            err_msg = str(e).lower()
            if "429" in err_msg or "rate limit" in err_msg or "500" in err_msg or "503" in err_msg:
                backoff = (2 ** attempt) + 1.0
                logger.warning("Groq call attempt %d failed (%s). Retrying in %.1fs...", attempt + 1, e, backoff)
                time.sleep(backoff)
            else:
                # Fatal request error (e.g. 400 Bad Request)
                raise e
    raise RuntimeError(f"Groq API failed after {max_retries} attempts: {last_err}")


def _extract_batch_vision(
    client: Groq,
    model: str,
    batch_slides: List[Tuple[int, str]],  # (slide_number, image_path)
) -> List[SlideVisionDescription]:
    """Analyzes a batch of <= 5 slides using VISION_MODEL in JSON mode."""
    slide_numbers = [s[0] for s in batch_slides]
    system_prompt = (
        "You are an expert presentation visual analyst. You only describe what is visible on each slide.\n"
        "Return ONLY a JSON object with this exact schema:\n"
        "{\n"
        '  "slides": [\n'
        "    {\n"
        '      "slide_number": int,\n'
        '      "title": "Slide header or headline",\n'
        '      "main_message": "Core concept communicated by this slide",\n'
        '      "visible_text": "Key text, bullets, labels, or numbers present",\n'
        '      "visuals": "Describe charts, diagrams, product mockups, trend direction, and metrics",\n'
        '      "text_density": "low" | "medium" | "high",\n'
        '      "readability_issues": ["list any font size, contrast, or clutter issues"]\n'
        "    }\n"
        "  ]\n"
        "}\n"
        f"You are analyzing slides {slide_numbers}. Provide an entry for each slide."
    )

    user_content: List[Dict[str, Any]] = [
        {"type": "text", "text": f"Analyze these {len(batch_slides)} slides in order and describe them strictly in JSON."}
    ]

    for slide_num, img_path in batch_slides:
        b64 = _encode_image_b64(img_path)
        user_content.append({"type": "text", "text": f"--- Slide {slide_num} ---"})
        user_content.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
        })

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_content},
    ]

    # Attempt 1
    raw = _call_groq_with_backoff(
        client=client,
        model=model,
        messages=messages,
        response_format={"type": "json_object"},
    )

    try:
        data = json.loads(raw)
        parsed = BatchVisionResponse.model_validate(data)
        if parsed.slides:
            return parsed.slides
    except Exception as exc:
        logger.warning("Stage B batch %s initial parse failed (%s). Attempting repair prompt...", slide_numbers, exc)

    # Attempt 2: Repair prompt
    repair_messages = messages + [
        {"role": "assistant", "content": raw},
        {"role": "user", "content": "Your previous response was not valid JSON conforming to the requested schema. Return valid JSON only with the key 'slides'."}
    ]
    raw_repair = _call_groq_with_backoff(
        client=client,
        model=model,
        messages=repair_messages,
        response_format={"type": "json_object"},
    )
    data_repair = json.loads(raw_repair)
    parsed_repair = BatchVisionResponse.model_validate(data_repair)
    return parsed_repair.slides


def extract_all_slides_vision(
    image_paths: List[str],
    client: Groq,
    model: str,
) -> List[SlideVisionDescription]:
    """Runs Stage B across all slides in batches of <= 5."""
    start_time = time.time()
    total_slides = len(image_paths)
    all_slides_numbered = [(i + 1, path) for i, path in enumerate(image_paths)]

    # Chunk into batches of <= 5
    batches: List[List[Tuple[int, str]]] = []
    for i in range(0, total_slides, GROQ_MAX_VISION_BATCH):
        batches.append(all_slides_numbered[i: i + GROQ_MAX_VISION_BATCH])

    descriptions: List[SlideVisionDescription] = []

    for batch in batches:
        batch_results = _extract_batch_vision(client, model, batch)
        descriptions.extend(batch_results)

    # Sort and verify slide numbering
    descriptions.sort(key=lambda s: s.slide_number)

    # If any slide was missed in model output, fill in a fallback entry
    existing_nums = {s.slide_number for s in descriptions}
    for i in range(1, total_slides + 1):
        if i not in existing_nums:
            descriptions.append(SlideVisionDescription(
                slide_number=i,
                title=f"Slide {i}",
                main_message="Presentation slide",
                visible_text="",
                visuals="Slide graphic",
                text_density="medium",
                readability_issues=[]
            ))
    descriptions.sort(key=lambda s: s.slide_number)

    elapsed = time.time() - start_time
    logger.info("Stage B (Vision Extraction): extracted %d slides in %.2fs", total_slides, elapsed)
    return descriptions


# ─────────────────────────────────────────────────────────────────────────────
# Stage C: Coaching Synthesis (TEXT_MODEL)
# ─────────────────────────────────────────────────────────────────────────────

def rescale_durations(slides: List[Dict[str, Any]], total_target_seconds: int) -> None:
    """
    Enforces that sum(target_duration_seconds) matches total_target_seconds within +-5%.
    Rescales proportionally if off.
    """
    if not slides or total_target_seconds <= 0:
        return

    current_sum = sum(s.get("target_duration_seconds", 30) for s in slides)
    if current_sum <= 0:
        per_slide = max(10, total_target_seconds // len(slides))
        for s in slides:
            s["target_duration_seconds"] = per_slide
        current_sum = sum(s["target_duration_seconds"] for s in slides)

    margin = abs(current_sum - total_target_seconds) / total_target_seconds
    if margin <= 0.05:
        return

    # Scale proportionally with a floor of 10s per slide
    ratio = total_target_seconds / current_sum
    scaled = [max(10, int(round(s.get("target_duration_seconds", 30) * ratio))) for s in slides]

    # Adjust difference on the last slide or largest slide
    diff = total_target_seconds - sum(scaled)
    scaled[-1] = max(10, scaled[-1] + diff)

    for i, s in enumerate(slides):
        s["target_duration_seconds"] = scaled[i]


def synthesize_deck_coaching(
    descriptions: List[SlideVisionDescription],
    audience: str,
    time_limit_seconds: int,
    goal: str,
    client: Groq,
    model: str,
    tone: Optional[str] = None,
) -> DeckCoachingResult:
    """
    Synthesizes slide descriptions and user context into complete structured coaching.
    """
    start_time = time.time()
    total_slides = len(descriptions)

    # Format descriptions for prompt
    desc_items = []
    for d in descriptions:
        desc_items.append(
            f"Slide {d.slide_number}: Title: '{d.title}'\n"
            f"  Main message: {d.main_message}\n"
            f"  Visuals: {d.visuals}\n"
            f"  Visible text: {d.visible_text}\n"
            f"  Text density: {d.text_density}\n"
            f"  Readability issues: {', '.join(d.readability_issues) if d.readability_issues else 'None'}"
        )
    formatted_slides = "\n\n".join(desc_items)

    # If extremely long, compress summaries to avoid token explosion
    if len(formatted_slides) > 25000:
        logger.info("Compressing slide descriptions for Stage C context budget...")
        formatted_slides = formatted_slides[:25000]

    system_prompt = (
        "You are an elite pitch coach preparing a speaker for a high-stakes presentation.\n"
        f"AUDIENCE: {audience}\n"
        f"GOAL: {goal or 'Deliver a persuasive presentation'}\n"
        f"TOTAL TIME LIMIT: {time_limit_seconds} seconds ({math.ceil(time_limit_seconds / 60)} minutes)\n"
        f"TONE: {tone or 'Persuasive, authoritative, engaging'}\n\n"
        "Return ONLY a JSON object matching this schema:\n"
        "{\n"
        '  "deck_summary": {\n'
        '    "story_arc": "3-4 concise sentences describing the overall narrative arc and flow.",\n'
        '    "missing_sections": ["e.g. Problem, Solution, Traction, Market, Unit Economics, Team, Ask"],\n'
        '    "overall_score": int between 0 and 100,\n'
        '    "top_3_fixes": ["3 most impactful strategic improvements to make"]\n'
        "  },\n"
        '  "slides": [\n'
        "    {\n"
        '      "slide_number": int,\n'
        '      "slide_title": "Clean slide title",\n'
        '      "target_duration_seconds": int (allocated time for this slide),\n'
        '      "key_takeaway": "Single sentence summarizing what the audience must remember",\n'
        '      "talking_points": ["3-5 short, punchy bullet points to say"],\n'
        '      "suggested_script": "Optional word-for-word spoken script (60-120 words)",\n'
        '      "transition_to_next": "Spoken hook bridging smoothly to the next slide",\n'
        '      "slide_critique": ["Specific constructive critiques regarding layout, clarity, or data"]\n'
        "    }\n"
        "  ]\n"
        "}\n\n"
        f"IMPORTANT TIME CONSTRAINT: The sum of all 'target_duration_seconds' MUST approximately equal {time_limit_seconds} seconds."
    )

    user_prompt = (
        f"Here are the descriptions of all {total_slides} slides in the deck:\n\n"
        f"{formatted_slides}\n\n"
        "Synthesize the complete coaching plan in valid JSON."
    )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    raw = _call_groq_with_backoff(
        client=client,
        model=model,
        messages=messages,
        response_format={"type": "json_object"},
    )

    try:
        data = json.loads(raw)
        result = DeckCoachingResult.model_validate(data)
    except Exception as exc:
        logger.warning("Stage C initial parse failed (%s). Retrying with repair...", exc)
        repair_messages = messages + [
            {"role": "assistant", "content": raw},
            {"role": "user", "content": "Return ONLY valid JSON matching the requested schema with 'deck_summary' and 'slides'."}
        ]
        raw_repair = _call_groq_with_backoff(
            client=client,
            model=model,
            messages=repair_messages,
            response_format={"type": "json_object"},
        )
        data = json.loads(raw_repair)
        result = DeckCoachingResult.model_validate(data)

    # Attach Stage B visuals / readability context to each slide result
    desc_by_num = {d.slide_number: d for d in descriptions}
    slide_dicts = [s.model_dump() for s in result.slides]

    # Enforce duration constraint in code (±5%)
    rescale_durations(slide_dicts, time_limit_seconds)

    # Rehydrate
    rehydrated_slides: List[SlideCoaching] = []
    for s_dict in slide_dicts:
        num = s_dict["slide_number"]
        desc = desc_by_num.get(num)
        if desc:
            s_dict["visuals"] = desc.visuals
            s_dict["text_density"] = desc.text_density
            s_dict["readability_issues"] = desc.readability_issues
        rehydrated_slides.append(SlideCoaching.model_validate(s_dict))

    result.slides = rehydrated_slides

    elapsed = time.time() - start_time
    logger.info("Stage C (Coaching Synthesis): completed in %.2fs", elapsed)
    return result


# ─────────────────────────────────────────────────────────────────────────────
# Rehearsal Mode: Slide-Aligned Audio Analysis
# ─────────────────────────────────────────────────────────────────────────────

# Standard and Hinglish/Tamil conversational fillers
SLIDE_FILLERS_SINGLE = {
    "um", "uh", "like", "actually", "basically", "so",
    "right", "literally", "well", "okay", "ah", "enna", "paa",
}
SLIDE_FILLERS_MULTI = {
    "you know", "i mean", "kind of", "sort of",
}
_STRIP_CHARS = ".,!?;:'\"()[]"


def count_slide_fillers(words: List[str]) -> Tuple[int, Dict[str, int]]:
    """Counts single and multi-word fillers in a list of words."""
    cleaned = [w.strip(_STRIP_CHARS).lower() for w in words if w.strip(_STRIP_CHARS)]
    breakdown: Dict[str, int] = {}
    total = 0

    for i, w in enumerate(cleaned):
        if w in SLIDE_FILLERS_SINGLE:
            breakdown[w] = breakdown.get(w, 0) + 1
            total += 1
        if i + 1 < len(cleaned):
            bigram = f"{w} {cleaned[i+1]}"
            if bigram in SLIDE_FILLERS_MULTI:
                breakdown[bigram] = breakdown.get(bigram, 0) + 1
                total += 1

    return total, breakdown


def split_transcript_by_slides(
    word_timestamps: List[Tuple[str, float, float]],
    slide_timestamps: List[Dict[str, Any]],
    total_audio_duration_seconds: float,
) -> Dict[int, Dict[str, Any]]:
    """
    Splits word-level timestamps across slides based on entered_at_ms transition timestamps.
    Returns: {slide_number: {"words": [...], "transcript": "...", "duration_seconds": float}}
    """
    sorted_markers = sorted(slide_timestamps, key=lambda m: m["entered_at_ms"])
    if not sorted_markers:
        return {}

    num_markers = len(sorted_markers)
    result: Dict[int, Dict[str, Any]] = {}

    for idx, marker in enumerate(sorted_markers):
        slide_num = marker["slide_number"]
        start_sec = marker["entered_at_ms"] / 1000.0

        if idx + 1 < num_markers:
            end_sec = sorted_markers[idx + 1]["entered_at_ms"] / 1000.0
        else:
            end_sec = max(start_sec, total_audio_duration_seconds)

        slide_duration = max(0.1, end_sec - start_sec)

        # Collect words spoken in [start_sec, end_sec)
        slide_words: List[Tuple[str, float, float]] = []
        for w, w_start, w_end in word_timestamps:
            if start_sec <= w_start < end_sec or (idx == num_markers - 1 and w_start >= start_sec):
                slide_words.append((w, w_start, w_end))

        slide_text = " ".join(w for w, _, _ in slide_words)
        result[slide_num] = {
            "words": slide_words,
            "transcript": slide_text,
            "duration_seconds": round(slide_duration, 1),
        }

    return result


def check_talking_points_coverage(
    talking_points: List[str],
    slide_transcript: str,
    client: Groq,
    model: str,
) -> Tuple[List[Dict[str, Any]], float]:
    """
    Asks TEXT_MODEL which talking points were covered in the spoken slide transcript.
    """
    if not talking_points:
        return [], 100.0

    if not slide_transcript.strip():
        items = [{"point": p, "covered": False, "evidence": None} for p in talking_points]
        return items, 0.0

    system_prompt = (
        "You are an objective pitch adjudicator checking if the speaker covered the intended slide talking points.\n"
        "Return ONLY a JSON object:\n"
        "{\n"
        '  "coverage": [\n'
        '    {"point": "point text", "covered": true/false, "evidence": "short quote of where they covered it or null"}\n'
        "  ]\n"
        "}"
    )

    user_prompt = (
        f"TALKING POINTS TO COVER:\n{json.dumps(talking_points)}\n\n"
        f"SPOKEN TRANSCRIPT:\n{slide_transcript}\n\n"
        "Evaluate which talking points were covered."
    )

    try:
        raw = _call_groq_with_backoff(
            client=client,
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
        )
        data = json.loads(raw)
        cov_list = data.get("coverage", [])
        if not cov_list:
            raise ValueError("Empty coverage list")
    except Exception as exc:
        logger.warning("Talking point coverage eval failed (%s), using keyword fallback", exc)
        cov_list = []
        transcript_lower = slide_transcript.lower()
        for p in talking_points:
            words_in_p = [w.lower() for w in p.split() if len(w) > 3]
            hit = any(w in transcript_lower for w in words_in_p) if words_in_p else False
            cov_list.append({"point": p, "covered": hit, "evidence": None})

    covered_count = sum(1 for c in cov_list if c.get("covered"))
    pct = round((covered_count / len(talking_points)) * 100, 1)
    return cov_list, pct


def run_slide_rehearsal_pipeline(
    audio_path: str,
    slide_timestamps: List[Dict[str, Any]],
    deck_data: Dict[str, Any],
    client: Groq,
    whisper_model: str,
    text_model: str,
) -> Dict[str, Any]:
    """
    Processes a complete deck rehearsal run with audio and slide swipe timestamps.
    """
    from sessions.coach_agent import run_feedback_agent
    from sessions.pipeline import _transcribe

    # 1. Transcribe audio with word-level timestamps using Whisper
    full_transcript, raw_word_tuples = _transcribe(audio_path, client, model=whisper_model)
    words = [(w.word, w.start, w.end) for w in raw_word_tuples]
    total_audio_dur = words[-1][2] if words else 0.0

    # 2. Split transcript per slide
    slide_splits = split_transcript_by_slides(words, slide_timestamps, total_audio_dur)

    slides_config = {s["slide_number"]: s for s in deck_data.get("slides", [])}
    slide_reports = []
    total_fillers = 0
    total_words_count = 0
    total_coverage_sum = 0.0

    # 3. Analyze each slide
    for marker in sorted(slide_timestamps, key=lambda m: m["entered_at_ms"]):
        s_num = marker["slide_number"]
        cfg = slides_config.get(s_num, {})
        split = slide_splits.get(s_num, {"words": [], "transcript": "", "duration_seconds": 0.0})

        s_words = split["words"]
        s_transcript = split["transcript"]
        s_duration = split["duration_seconds"]

        # Word count & WPM
        num_words = len(s_words)
        total_words_count += num_words
        wpm = round((num_words * 60.0) / s_duration) if s_duration > 0 else 0

        # Filler count
        f_count, f_breakdown = count_slide_fillers([w for w, _, _ in s_words])
        total_fillers += f_count

        # Talking points coverage
        target_points = cfg.get("talking_points", [])
        cov_items, cov_pct = check_talking_points_coverage(target_points, s_transcript, client, text_model)
        total_coverage_sum += cov_pct

        # Per-slide Coach Agent advice
        metrics = {
            "wpm": wpm,
            "duration_seconds": s_duration,
            "target_duration_seconds": cfg.get("target_duration_seconds", 30),
            "filler_count": f_count,
            "coverage_percentage": cov_pct,
        }
        slide_coach_feedback = []
        try:
            agent_feedback = run_feedback_agent(
                client=client,
                model=text_model,
                transcript=s_transcript,
                words=s_words,
                metrics=metrics,
                feedback_style="Encouraging & Constructive",
                fillers_single=SLIDE_FILLERS_SINGLE,
                fillers_multi=SLIDE_FILLERS_MULTI,
            )
            if agent_feedback:
                slide_coach_feedback = agent_feedback
        except Exception as exc:
            logger.warning("Slide coach agent failed for slide %d: %s", s_num, exc)

        slide_reports.append({
            "slide_number": s_num,
            "slide_title": cfg.get("slide_title", f"Slide {s_num}"),
            "target_duration_seconds": cfg.get("target_duration_seconds", 30),
            "actual_duration_seconds": s_duration,
            "wpm": wpm,
            "filler_count": f_count,
            "filler_breakdown": f_breakdown,
            "transcript": s_transcript,
            "talking_points_coverage": cov_items,
            "coverage_percentage": cov_pct,
            "ai_feedback": slide_coach_feedback,
        })

    # Overall Metrics
    overall_duration = sum(r["actual_duration_seconds"] for r in slide_reports)
    target_total_duration = deck_data.get("time_limit_seconds", 180)
    overall_wpm = round((total_words_count * 60.0) / overall_duration) if overall_duration > 0 else 0
    avg_coverage = round(total_coverage_sum / len(slide_reports), 1) if slide_reports else 0.0

    # Overall feedback synthesis
    overall_prompt = (
        f"Deck target time: {target_total_duration}s. Spoken time: {round(overall_duration, 1)}s.\n"
        f"Overall WPM: {overall_wpm}. Fillers: {total_fillers}. Talking point coverage: {avg_coverage}%.\n"
        "Return ONLY a JSON array with 3 prioritized improvement bullet points for the next rehearsal:\n"
        '["bullet 1", "bullet 2", "bullet 3"]'
    )
    try:
        raw_top = _call_groq_with_backoff(
            client=client,
            model=text_model,
            messages=[{"role": "user", "content": overall_prompt}],
            response_format={"type": "json_object"},
        )
        parsed_top = json.loads(raw_top)
        improvements = parsed_top if isinstance(parsed_top, list) else list(parsed_top.values())[0]
        if not isinstance(improvements, list):
            improvements = ["Practice transitions between slides", "Slow down on key data slides", "Aim closer to target time"]
    except Exception:
        improvements = ["Practice transitions between slides", "Slow down on key data slides", "Aim closer to target time"]

    return {
        "total_duration_seconds": round(overall_duration, 1),
        "time_limit_seconds": target_total_duration,
        "overall_wpm": overall_wpm,
        "overall_filler_count": total_fillers,
        "overall_coverage_percentage": avg_coverage,
        "overall_feedback": improvements[:3],
        "slide_reports": slide_reports,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Q&A Prep Pipeline
# ─────────────────────────────────────────────────────────────────────────────

def generate_qa_questions(
    deck_summary: Dict[str, Any],
    slides: List[Dict[str, Any]],
    audience: str,
    client: Groq,
    model: str,
) -> List[Dict[str, Any]]:
    """Generates 5-8 tough audience-specific presentation questions with rationale."""
    slides_context = []
    for s in slides:
        slides_context.append(f"Slide {s.get('slide_number')}: {s.get('slide_title')} - Takeaway: {s.get('key_takeaway')}")

    system_prompt = (
        f"You are a challenging panel of {audience}. You examine pitch decks to ask critical questions.\n"
        "Generate between 5 and 8 tough, realistic, penetrating questions.\n"
        "Return ONLY a JSON object:\n"
        "{\n"
        '  "questions": [\n'
        "    {\n"
        '      "id": "q1",\n'
        '      "question": "Clear, direct question",\n'
        '      "why_they_ask": "Strategic reason the audience cares about this",\n'
        '      "targeted_slide_number": int or null\n'
        "    }\n"
        "  ]\n"
        "}"
    )

    user_prompt = (
        f"DECK SUMMARY:\n{json.dumps(deck_summary)}\n\n"
        f"SLIDES:\n" + "\n".join(slides_context)
    )

    raw = _call_groq_with_backoff(
        client=client,
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        response_format={"type": "json_object"},
    )
    data = json.loads(raw)
    return data.get("questions", [])


def evaluate_qa_answer(
    question: str,
    why_they_ask: str,
    audio_path: str,
    client: Groq,
    whisper_model: str,
    text_model: str,
) -> Dict[str, Any]:
    """Transcribes audio answer and grades clarity, directness, evidence, confidence."""
    from sessions.pipeline import _transcribe

    transcript, _ = _transcribe(audio_path, client, model=whisper_model)

    system_prompt = (
        "You are an executive pitch coach evaluating a candidate's answer to a tough Q&A question.\n"
        "Evaluate the response on four criteria (0-100):\n"
        "1. clarity (clear, articulate speech)\n"
        "2. directness (answered immediately without dodging)\n"
        "3. evidence (provided metrics, examples, or proof)\n"
        "4. confidence (assertive, authoritative tone)\n\n"
        "Return ONLY a JSON object:\n"
        "{\n"
        '  "clarity_score": int (0-100),\n'
        '  "directness_score": int (0-100),\n'
        '  "evidence_score": int (0-100),\n'
        '  "confidence_score": int (0-100),\n'
        '  "overall_score": int (0-100),\n'
        '  "critique": "Concise 2-3 sentence coaching feedback on how they handled the question",\n'
        '  "sample_better_answer": "A punchy, model 3-4 sentence answer they should have given instead"\n'
        "}"
    )

    user_prompt = (
        f"QUESTION: {question}\n"
        f"WHY THEY ASKED: {why_they_ask}\n"
        f"SPOKEN ANSWER TRANSCRIPT:\n{transcript}"
    )

    raw = _call_groq_with_backoff(
        client=client,
        model=text_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        response_format={"type": "json_object"},
    )
    eval_data = json.loads(raw)
    eval_data["spoken_transcript"] = transcript
    return eval_data
