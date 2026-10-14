"""PDF Report Generation Service for Pitch Coach.

Uses PyMuPDF (pymupdf) to generate high-fidelity, beautifully styled PDF performance
evaluations and weekly coaching progress reports with zero extra external dependencies.
"""
from datetime import datetime, timezone
import textwrap
from typing import Any, Dict, List, Optional

import pymupdf as fitz

from models import PracticeSession


# ── Color Palette (RGB in 0.0 - 1.0) ─────────────────────────────────────────
COLOR_DARK_PURPLE = (0.11, 0.08, 0.22)     # #1C1438 - Primary deep tone
COLOR_PRIMARY_PURPLE = (0.42, 0.36, 0.91)  # #6C5CE7 - Pitch Coach purple
COLOR_PRIMARY_LIGHT = (0.55, 0.49, 0.96)   # #8C7DFA - Accent
COLOR_CARD_BG = (0.965, 0.968, 0.985)      # Soft card background
COLOR_CARD_BORDER = (0.87, 0.88, 0.92)     # Subtle card border
COLOR_TEXT_PRIMARY = (0.12, 0.12, 0.16)    # Charcoal primary text
COLOR_TEXT_SECONDARY = (0.44, 0.45, 0.52)  # Muted slate caption
COLOR_WHITE = (1.0, 1.0, 1.0)
COLOR_SUCCESS = (0.06, 0.65, 0.41)         # #10B981 - Green
COLOR_WARNING = (0.95, 0.60, 0.07)         # #F59E0B - Amber
COLOR_ALERT = (0.93, 0.27, 0.27)           # #EF4444 - Red


def _score_color(score: float) -> tuple[float, float, float]:
    if score >= 80.0:
        return COLOR_SUCCESS
    elif score >= 60.0:
        return COLOR_WARNING
    return COLOR_ALERT


def _pacing_assessment(wpm: float) -> tuple[str, tuple[float, float, float]]:
    if 120.0 <= wpm <= 160.0:
        return "Optimal (120-160 WPM)", COLOR_SUCCESS
    elif 100.0 <= wpm < 120.0:
        return "Slightly Deliberate (100-120 WPM)", COLOR_WARNING
    elif 160.0 < wpm <= 180.0:
        return "Slightly Fast (160-180 WPM)", COLOR_WARNING
    elif wpm < 100.0:
        return "Hesitant / Slow (<100 WPM)", COLOR_ALERT
    else:
        return "Rushing (>180 WPM)", COLOR_ALERT


def generate_session_pdf_report(
    session: PracticeSession,
    user_name: str = "Pitch Coach Member",
) -> bytes:
    """Generates a comprehensive, branded 1-page A4 PDF session performance report."""
    doc = fitz.open()
    page = doc.new_page(width=595.3, height=841.9)  # Standard A4: 595 x 842 pt

    # 1. Header Hero Card
    header_rect = fitz.Rect(30, 30, 565, 125)
    page.draw_rect(header_rect, color=COLOR_DARK_PURPLE, fill=COLOR_DARK_PURPLE)

    page.insert_text(
        fitz.Point(50, 58),
        "PITCH COACH  |  SESSION PERFORMANCE REPORT",
        fontsize=9,
        fontname="helv",
        color=COLOR_PRIMARY_LIGHT,
    )

    # Title / Topic
    topic = session.topic_or_question or "Speech Rehearsal Take"
    if len(topic) > 65:
        topic = topic[:62] + "..."
    page.insert_text(
        fitz.Point(50, 84),
        topic,
        fontsize=16,
        fontname="helv",
        color=COLOR_WHITE,
    )

    # Metadata subline
    date_str = session.created_at.strftime("%B %d, %Y  *  %H:%M UTC") if session.created_at else "Recently"
    duration_min = f"{session.duration_seconds:.1f}s" if session.duration_seconds < 60 else f"{int(session.duration_seconds // 60)}m {int(session.duration_seconds % 60)}s"
    mode_title = (session.mode or "Interview").replace("_", " ").title()
    meta_line = f"Speaker: {user_name}   •   Mode: {mode_title}   •   Duration: {duration_min}   •   {date_str}"
    page.insert_text(
        fitz.Point(50, 108),
        meta_line,
        fontsize=9,
        fontname="helv",
        color=(0.80, 0.80, 0.88),
    )

    # 2. Score Hero Cards
    # Box 1: Overall Score
    overall = session.overall_score or 0.0
    overall_color = _score_color(overall)
    overall_rect = fitz.Rect(30, 138, 200, 225)
    page.draw_rect(overall_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(45, 158), "OVERALL SCORE", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(45, 196), f"{int(round(overall))}", fontsize=34, fontname="helv", color=overall_color)
    page.insert_text(fitz.Point(100, 185), "/ 100", fontsize=12, fontname="helv", color=COLOR_TEXT_SECONDARY)

    rating_str = "Exceptional" if overall >= 88 else "Proficient" if overall >= 75 else "Developing" if overall >= 60 else "Needs Practice"
    page.insert_text(fitz.Point(45, 214), f"Rating: {rating_str}", fontsize=9, fontname="helv", color=overall_color)

    # Box 2: Clarity Score
    clarity_rect = fitz.Rect(210, 138, 320, 225)
    page.draw_rect(clarity_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(222, 158), "CLARITY", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(222, 195), f"{int(round(session.clarity_score or 0.0))}%", fontsize=24, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(222, 214), "Articulation & Flow", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    # Box 3: Confidence Score
    conf_rect = fitz.Rect(330, 138, 440, 225)
    page.draw_rect(conf_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(342, 158), "CONFIDENCE", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(342, 195), f"{int(round(session.confidence_score or 0.0))}%", fontsize=24, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(342, 214), "Energy & Presence", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    # Box 4: Structure / Vocal Quality
    fourth_title = "STRUCTURE" if session.structure_score is not None else "VOCAL DYNAMICS"
    fourth_val = int(round(session.structure_score or session.pitch_variation_score or 80.0))
    fourth_sub = "Template Adherence" if session.structure_score is not None else "Pitch Variation"
    struct_rect = fitz.Rect(450, 138, 565, 225)
    page.draw_rect(struct_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(462, 158), fourth_title, fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(462, 195), f"{fourth_val}%", fontsize=24, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(462, 214), fourth_sub, fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    # 3. Delivery Metrics Table Card
    metrics_rect = fitz.Rect(30, 238, 565, 335)
    page.draw_rect(metrics_rect, color=COLOR_CARD_BORDER, fill=COLOR_WHITE)

    page.insert_text(fitz.Point(45, 258), "CORE DELIVERY METRICS", fontsize=10, fontname="helv", color=COLOR_DARK_PURPLE)

    pace_label, pace_color = _pacing_assessment(session.wpm)
    wpm_str = f"{int(round(session.wpm))} WPM"
    fillers_per_100 = (session.filler_word_count / max(1, (session.wpm * (session.duration_seconds / 60.0)))) * 100 if session.duration_seconds > 0 else float(session.filler_word_count)

    # Metric Row 1: Pacing
    page.insert_text(fitz.Point(45, 280), "Speaking Pace (WPM):", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(180, 280), wpm_str, fontsize=9, fontname="helv", color=COLOR_TEXT_PRIMARY)
    page.insert_text(fitz.Point(270, 280), f"Status: {pace_label}", fontsize=9, fontname="helv", color=pace_color)

    # Metric Row 2: Filler Words
    page.insert_text(fitz.Point(45, 300), "Filler Words:", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(180, 300), f"{session.filler_word_count} total ({fillers_per_100:.1f} / 100 words)", fontsize=9, fontname="helv", color=COLOR_TEXT_PRIMARY)
    filler_status = "Clean" if fillers_per_100 <= 1.5 else "Moderate" if fillers_per_100 <= 3.5 else "Frequent"
    filler_col = COLOR_SUCCESS if fillers_per_100 <= 1.5 else COLOR_WARNING if fillers_per_100 <= 3.5 else COLOR_ALERT
    page.insert_text(fitz.Point(380, 300), f"Status: {filler_status}", fontsize=9, fontname="helv", color=filler_col)

    # Metric Row 3: Pauses & Vocal Consistency
    avg_pause = f"{session.avg_pause_length:.1f}s" if session.avg_pause_length > 0 else "0.0s"
    page.insert_text(fitz.Point(45, 320), "Pauses & Cadence:", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)
    vol_consist = f"{int(round(session.volume_consistency_score))}%" if session.volume_consistency_score else "N/A"
    page.insert_text(fitz.Point(180, 320), f"{session.pause_count} pauses (avg {avg_pause})  •  Volume Stability: {vol_consist}", fontsize=9, fontname="helv", color=COLOR_TEXT_PRIMARY)

    # 4. Energy Sparkline / Waveform Chart
    chart_rect = fitz.Rect(30, 348, 565, 430)
    page.draw_rect(chart_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(45, 368), "VOCAL DELIVERY ENERGY CURVE", fontsize=10, fontname="helv", color=COLOR_DARK_PURPLE)

    curve = session.energy_curve or []
    if len(curve) >= 2:
        # Draw axes
        axis_x0, axis_y0 = 50.0, 415.0
        axis_w, axis_h = 495.0, 35.0
        min_v, max_v = min(curve), max(curve)
        val_range = max(1e-4, max_v - min_v)
        step_x = axis_w / float(len(curve) - 1)

        prev_pt = None
        for i, val in enumerate(curve):
            norm_val = (val - min_v) / val_range
            pt = fitz.Point(axis_x0 + (i * step_x), axis_y0 - (norm_val * axis_h))
            if prev_pt is not None:
                page.draw_line(prev_pt, pt, color=COLOR_PRIMARY_PURPLE, width=1.5)
            prev_pt = pt

        page.insert_text(fitz.Point(45, 423), "0s (Start)", fontsize=7, fontname="helv", color=COLOR_TEXT_SECONDARY)
        page.insert_text(fitz.Point(510, 423), f"{duration_min} (End)", fontsize=7, fontname="helv", color=COLOR_TEXT_SECONDARY)
    else:
        page.insert_text(
            fitz.Point(50, 395),
            "Energy and pitch cadence recorded stably throughout presentation duration.",
            fontsize=9,
            fontname="helv",
            color=COLOR_TEXT_SECONDARY,
        )

    # 5. Top 3 Actionable Coaching Recommendations
    feedback_header_y = 448
    page.insert_text(fitz.Point(30, feedback_header_y), "TOP ACTIONABLE COACHING RECOMMENDATIONS", fontsize=11, fontname="helv", color=COLOR_DARK_PURPLE)

    feedback_items = session.ai_feedback or []
    # If no AI feedback items, provide high-value defaults based on metrics
    if not feedback_items:
        feedback_items = [
            {"category": "Pacing", "severity": "tip", "message": f"Your pace was {int(round(session.wpm))} WPM. Aim to maintain 120-160 WPM during critical slides to ensure your message lands cleanly."},
            {"category": "Pauses", "severity": "tip", "message": "Use deliberate 1-second pauses before major takeaways instead of filler words to project authority."},
            {"category": "Clarity", "severity": "tip", "message": "Emphasize metric achievements with vocal stress to make your quantifiable traction memorable."},
        ]

    top_items = feedback_items[:3]
    cur_y = 462.0
    for idx, item in enumerate(top_items):
        cat = item.get("category", "Coaching Tip").title()
        msg = item.get("message", "Continue regular practice to refine pacing and clarity.")
        sev = item.get("severity", "tip").lower()
        badge_color = COLOR_ALERT if sev == "warning" else COLOR_WARNING if sev == "important" else COLOR_PRIMARY_PURPLE

        card_rect = fitz.Rect(30, cur_y, 565, cur_y + 68)
        page.draw_rect(card_rect, color=COLOR_CARD_BORDER, fill=COLOR_WHITE)

        # Number & Category Pill
        page.insert_text(fitz.Point(45, cur_y + 18), f"{idx + 1}.  {cat}", fontsize=9, fontname="helv", color=badge_color)

        # Wrapped message text
        wrapped_lines = textwrap.wrap(msg, width=82)
        text_y = cur_y + 32
        for line in wrapped_lines[:2]:
            page.insert_text(fitz.Point(45, text_y), line, fontsize=8.5, fontname="helv", color=COLOR_TEXT_PRIMARY)
            text_y += 13

        cur_y += 76

    # 6. Transcript Excerpt (if present)
    if session.transcript and cur_y < 730:
        transcript_box_h = min(60.0, 780.0 - cur_y)
        trans_rect = fitz.Rect(30, cur_y, 565, cur_y + transcript_box_h)
        page.draw_rect(trans_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
        page.insert_text(fitz.Point(45, cur_y + 16), "TRANSCRIPT EXCERPT", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
        cleaned_trans = " ".join(session.transcript.split())
        wrapped_trans = textwrap.wrap(cleaned_trans, width=88)
        trans_y = cur_y + 30
        for line in wrapped_trans[:2]:
            page.insert_text(fitz.Point(45, trans_y), f'"{line}"', fontsize=8, fontname="helv", color=COLOR_TEXT_PRIMARY)
            trans_y += 12

    # 7. Footer
    footer_y = 818
    page.draw_line(fitz.Point(30, footer_y - 10), fitz.Point(565, footer_y - 10), color=COLOR_CARD_BORDER, width=0.8)
    page.insert_text(
        fitz.Point(30, footer_y),
        "Generated by Pitch Coach AI  •  Confidential Performance Evaluation  •  pitchcoach.ai",
        fontsize=8,
        fontname="helv",
        color=COLOR_TEXT_SECONDARY,
    )
    page.insert_text(
        fitz.Point(525, footer_y),
        "Page 1 of 1",
        fontsize=8,
        fontname="helv",
        color=COLOR_TEXT_SECONDARY,
    )

    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes


def generate_weekly_pdf_report(
    sessions: List[PracticeSession],
    user_name: str = "Pitch Coach Member",
) -> bytes:
    """Generates a weekly coaching progress report aggregating up to 7 days of takes."""
    doc = fitz.open()
    page = doc.new_page(width=595.3, height=841.9)

    # 1. Header Hero Card
    header_rect = fitz.Rect(30, 30, 565, 125)
    page.draw_rect(header_rect, color=COLOR_DARK_PURPLE, fill=COLOR_DARK_PURPLE)

    page.insert_text(
        fitz.Point(50, 58),
        "PITCH COACH  |  WEEKLY PROGRESS REPORT",
        fontsize=9,
        fontname="helv",
        color=COLOR_PRIMARY_LIGHT,
    )

    page.insert_text(
        fitz.Point(50, 84),
        f"Weekly Rehearsal Summary for {user_name}",
        fontsize=16,
        fontname="helv",
        color=COLOR_WHITE,
    )

    now_str = datetime.now(timezone.utc).strftime("%B %d, %Y")
    page.insert_text(
        fitz.Point(50, 108),
        f"Generated on {now_str}   •   Past 7 Days Rehearsal Analytics",
        fontsize=9,
        fontname="helv",
        color=(0.80, 0.80, 0.88),
    )

    # Aggregate metrics
    count = len(sessions)
    total_sec = sum(s.duration_seconds for s in sessions)
    avg_score = (sum(s.overall_score for s in sessions) / count) if count > 0 else 0.0
    avg_wpm = (sum(s.wpm for s in sessions) / count) if count > 0 else 0.0
    total_fillers = sum(s.filler_word_count for s in sessions)
    avg_clarity = (sum(s.clarity_score for s in sessions) / count) if count > 0 else 0.0

    # 2. Key Metrics Row
    c1 = fitz.Rect(30, 138, 155, 220)
    page.draw_rect(c1, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(42, 158), "TOTAL SESSIONS", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(42, 192), f"{count}", fontsize=28, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(42, 210), f"{int(total_sec // 60)} min practice", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    c2 = fitz.Rect(165, 138, 290, 220)
    page.draw_rect(c2, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(177, 158), "AVG SCORE", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(177, 192), f"{int(round(avg_score))}", fontsize=28, fontname="helv", color=_score_color(avg_score))
    page.insert_text(fitz.Point(177, 210), "/ 100 overall", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    c3 = fitz.Rect(300, 138, 425, 220)
    page.draw_rect(c3, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(312, 158), "AVG PACING", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(312, 192), f"{int(round(avg_wpm))}", fontsize=28, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(312, 210), "Target: 120-160 WPM", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    c4 = fitz.Rect(435, 138, 565, 220)
    page.draw_rect(c4, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(447, 158), "CLARITY AVG", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(447, 192), f"{int(round(avg_clarity))}%", fontsize=28, fontname="helv", color=COLOR_DARK_PURPLE)
    page.insert_text(fitz.Point(447, 210), f"{total_fillers} total fillers", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)

    # 3. Sessions Breakdown Table
    table_rect = fitz.Rect(30, 235, 565, 520)
    page.draw_rect(table_rect, color=COLOR_CARD_BORDER, fill=COLOR_WHITE)
    page.insert_text(fitz.Point(45, 256), "RECENT REHEARSALS THIS WEEK", fontsize=10, fontname="helv", color=COLOR_DARK_PURPLE)

    # Table Header
    page.draw_line(fitz.Point(45, 268), fitz.Point(550, 268), color=COLOR_CARD_BORDER, width=0.8)
    page.insert_text(fitz.Point(45, 280), "DATE / TOPIC", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(320, 280), "MODE", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(400, 280), "WPM", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.insert_text(fitz.Point(480, 280), "SCORE", fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
    page.draw_line(fitz.Point(45, 286), fitz.Point(550, 286), color=COLOR_CARD_BORDER, width=0.8)

    row_y = 302.0
    for s in sessions[:8]:
        d_str = s.created_at.strftime("%b %d") if s.created_at else "Recent"
        top = (s.topic_or_question or "Practice")[:38]
        page.insert_text(fitz.Point(45, row_y), f"{d_str} - {top}", fontsize=8, fontname="helv", color=COLOR_TEXT_PRIMARY)
        page.insert_text(fitz.Point(320, row_y), (s.mode or "interview").title()[:12], fontsize=8, fontname="helv", color=COLOR_TEXT_SECONDARY)
        page.insert_text(fitz.Point(400, row_y), f"{int(round(s.wpm))} WPM", fontsize=8, fontname="helv", color=COLOR_TEXT_PRIMARY)
        page.insert_text(fitz.Point(480, row_y), f"{int(round(s.overall_score))}/100", fontsize=8, fontname="helv", color=_score_color(s.overall_score))
        row_y += 24

    if not sessions:
        page.insert_text(fitz.Point(45, 310), "No recorded sessions this week. Rehearse a take to see your progress curve!", fontsize=9, fontname="helv", color=COLOR_TEXT_SECONDARY)

    # 4. Weekly Focus Recommendations
    rec_rect = fitz.Rect(30, 535, 565, 760)
    page.draw_rect(rec_rect, color=COLOR_CARD_BORDER, fill=COLOR_CARD_BG)
    page.insert_text(fitz.Point(45, 558), "WEEKLY COACHING FOCUS & NEXT STEPS", fontsize=10, fontname="helv", color=COLOR_DARK_PURPLE)

    focus_items = [
        "1. Maintain Cadence Consistency: Practice within the 120-160 WPM band to ensure maximum listener comprehension.",
        "2. Replace Fillers with Power Pauses: A deliberate 1-second silence sounds confident and allows your audience to digest complex data.",
        "3. Emphasize Core Value Proposition: State quantifiable metrics clearly during the first 60 seconds of your delivery.",
    ]
    f_y = 582.0
    for f in focus_items:
        page.insert_text(fitz.Point(45, f_y), f, fontsize=8.5, fontname="helv", color=COLOR_TEXT_PRIMARY)
        f_y += 24

    # 5. Footer
    footer_y = 818
    page.draw_line(fitz.Point(30, footer_y - 10), fitz.Point(565, footer_y - 10), color=COLOR_CARD_BORDER, width=0.8)
    page.insert_text(
        fitz.Point(30, footer_y),
        "Generated by Pitch Coach AI  •  Confidential Performance Evaluation  •  pitchcoach.ai",
        fontsize=8,
        fontname="helv",
        color=COLOR_TEXT_SECONDARY,
    )
    page.insert_text(
        fitz.Point(525, footer_y),
        "Page 1 of 1",
        fontsize=8,
        fontname="helv",
        color=COLOR_TEXT_SECONDARY,
    )

    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes
