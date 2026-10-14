"""
Resume Analysis & Interview Question Generation Pipeline.
Extracts candidate projects, skills, and synthesizes 5 behavioral + 5 technical questions
tied specifically to candidate projects and skills (and JD if provided).
"""
import json
import logging
import time
from typing import Dict, List, Optional
from pydantic import BaseModel, Field
from groq import Groq

from config import get_settings
from resume.sanitizer import sanitize_pii

logger = logging.getLogger(__name__)


class ResumeInterviewQuestions(BaseModel):
    candidate_projects: List[str] = Field(default_factory=list)
    candidate_skills: List[str] = Field(default_factory=list)
    behavioral_questions: List[str] = Field(
        default_factory=lambda: [
            "Tell me about a challenging situation you encountered in your key project and how you resolved it.",
            "Describe a time when you had to adapt to a sudden requirement change.",
            "How do you prioritize competing deadlines across multiple project deliverables?",
            "Tell me about a disagreement you had with a team member and how you reached consensus.",
            "What has been your most impactful achievement and what was your specific contribution?",
        ]
    )
    technical_questions: List[str] = Field(
        default_factory=lambda: [
            "Explain the architectural trade-offs you made in your primary project implementation.",
            "How do you ensure test coverage, reliability, and edge case handling in your codebase?",
            "Describe how you profile and optimize performance bottlenecks in production systems.",
            "Walk me through how data flows from the client to persistent storage in your applications.",
            "How do you approach API design, versioning, and backwards compatibility?",
        ]
    )
    sanitized_snippet: Optional[str] = None


_FALLBACK_QUESTIONS = ResumeInterviewQuestions(
    candidate_projects=["Primary Software Project", "Distributed System / App"],
    candidate_skills=["System Design", "Problem Solving", "Modern Software Architecture"],
)


def generate_resume_questions(
    sanitized_resume_text: str,
    jd_text: Optional[str] = None,
    groq_api_key: Optional[str] = None,
    llm_model: Optional[str] = None,
) -> ResumeInterviewQuestions:
    """
    Generates tailored behavioral and technical interview questions based on
    candidate projects, skills, and the optional job description text.
    """
    settings = get_settings()
    api_key = groq_api_key or settings.GROQ_API_KEY or settings.GROQ_AUDIO_API_KEY
    model = llm_model or settings.GROQ_LLM_MODEL or "llama-3.3-70b-versatile"

    # Always ensure text is sanitized (no PII)
    clean_resume = sanitize_pii(sanitized_resume_text)
    clean_jd = sanitize_pii(jd_text) if jd_text else None

    # Redacted preview snippet for transparency
    snippet = clean_resume[:300] + "..." if len(clean_resume) > 300 else clean_resume

    if not api_key:
        logger.warning("[resume_pipeline] No Groq API key configured; returning structured fallback questions.")
        res = _FALLBACK_QUESTIONS.model_copy()
        res.sanitized_snippet = snippet
        return res

    system_prompt = (
        "You are an expert technical interviewer and placement coach. "
        "Analyze the candidate's resume (and optional job description) and extract the key projects and skills. "
        "Then synthesize exactly 5 high-yield behavioral questions and 5 technical questions. "
        "Questions MUST directly probe specific details from the candidate's listed projects and skills. "
        "If a Job Description is provided, align the technical questions with the role requirements. "
        "Output ONLY valid JSON adhering strictly to the schema."
    )

    prompt = f"""CANDIDATE RESUME (PII Redacted):
\"\"\"{clean_resume[:4000]}\"\"\"

{f"JOB DESCRIPTION:\n\"\"\"{clean_jd[:2000]}\"\"\"\n" if clean_jd else ""}

Return a JSON object with this exact structure:
{{
  "candidate_projects": ["<Project 1 name and brief focus>", "<Project 2 name and brief focus>"],
  "candidate_skills": ["<Skill 1>", "<Skill 2>", "<Skill 3>"],
  "behavioral_questions": [
    "<Behavioral Question 1 probing a real situation in their project>",
    "<Behavioral Question 2 on teamwork/conflict>",
    "<Behavioral Question 3 on ambiguity/deadlines>",
    "<Behavioral Question 4 on learning from failure/mistakes>",
    "<Behavioral Question 5 on leadership/ownership>"
  ],
  "technical_questions": [
    "<Technical Question 1 probing deep architectural details of their project>",
    "<Technical Question 2 probing their primary framework/language>",
    "<Technical Question 3 probing data structures / storage / caching>",
    "<Technical Question 4 probing debugging / scale / performance>",
    "<Technical Question 5 probing testing / security / deployment>"
  ]
}}"""

    start_time = time.perf_counter()
    try:
        client = Groq(api_key=api_key)
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            max_tokens=1400,
            response_format={"type": "json_object"},
        )
        duration_ms = (time.perf_counter() - start_time) * 1000.0
        usage = getattr(resp, "usage", None)
        prompt_tokens = getattr(usage, "prompt_tokens", 0) if usage else 0
        completion_tokens = getattr(usage, "completion_tokens", 0) if usage else 0

        logger.info(
            "[resume_pipeline] Groq call successful: model=%s duration=%.1fms tokens=%d/%d",
            model,
            duration_ms,
            prompt_tokens,
            completion_tokens,
        )

        content = resp.choices[0].message.content or "{}"
        data = json.loads(content)

        behavioral = data.get("behavioral_questions") or []
        technical = data.get("technical_questions") or []
        projects = data.get("candidate_projects") or []
        skills = data.get("candidate_skills") or []

        # Ensure we have questions; if fewer than 5, supplement from fallbacks
        if len(behavioral) < 5:
            behavioral.extend(_FALLBACK_QUESTIONS.behavioral_questions[len(behavioral):5])
        if len(technical) < 5:
            technical.extend(_FALLBACK_QUESTIONS.technical_questions[len(technical):5])

        return ResumeInterviewQuestions(
            candidate_projects=projects[:6],
            candidate_skills=skills[:10],
            behavioral_questions=behavioral[:5],
            technical_questions=technical[:5],
            sanitized_snippet=snippet,
        )

    except Exception as exc:
        logger.error("[resume_pipeline] Groq question synthesis error: %s", exc)
        fallback = _FALLBACK_QUESTIONS.model_copy()
        fallback.sanitized_snippet = snippet
        return fallback
