"""
Pitch Templates Registry.
Data-driven configuration for interview & pitch templates:
- Investor Pitch (180s)
- Hackathon Demo (120s)
- Elevator Pitch (60s)
- Academic Viva / Defense (300s)

Adding a new template requires only a data entry in TEMPLATE_REGISTRY.
"""
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class TemplateSection(BaseModel):
    id: str
    name: str
    description: str
    weight: float = Field(..., ge=0, le=100, description="Section weight percentage in structure score")
    keywords: List[str] = Field(default_factory=list, description="Keywords indicating section coverage")


class PitchTemplate(BaseModel):
    id: str
    title: str
    description: str
    target_duration_seconds: int = Field(..., ge=15, le=600)
    sections: List[TemplateSection]
    rubric: Dict[str, str] = Field(..., description="Scoring criteria and guidelines for LLM evaluation")
    coaching_focus: str = Field(..., description="Primary focus area for the AI coach")


TEMPLATE_REGISTRY: Dict[str, PitchTemplate] = {
    "investor_pitch": PitchTemplate(
        id="investor_pitch",
        title="Investor Pitch",
        description="Raise seed/Series A capital by demonstrating urgent problem, defensible moats, traction, and clear use of funds.",
        target_duration_seconds=180,
        sections=[
            TemplateSection(
                id="hook_problem",
                name="Hook & Problem",
                description="Painful customer problem, market timing, and market validation.",
                weight=20.0,
                keywords=["problem", "pain", "market", "customers", "struggle", "gap", "industry"],
            ),
            TemplateSection(
                id="solution_product",
                name="Solution & Product",
                description="Unique value proposition, demo walkthrough, and unfair technical advantage.",
                weight=25.0,
                keywords=["solution", "platform", "product", "algorithm", "advantage", "proprietary", "ai"],
            ),
            TemplateSection(
                id="traction_market",
                name="Traction & TAM",
                description="Revenue, users, ARR, customer retention, growth rate, and market size.",
                weight=25.0,
                keywords=["traction", "revenue", "growth", "users", "arr", "tam", "customers", "retention"],
            ),
            TemplateSection(
                id="business_model",
                name="Business Model",
                description="Monetization, pricing tiers, unit economics, LTV/CAC, and margins.",
                weight=15.0,
                keywords=["pricing", "subscription", "business model", "margins", "ltv", "cac", "monetization"],
            ),
            TemplateSection(
                id="the_ask",
                name="The Ask & Use of Funds",
                description="Capital required, hiring roadmap, milestone targets, and runaway.",
                weight=15.0,
                keywords=["raising", "ask", "capital", "milestones", "use of funds", "runway", "hiring"],
            ),
        ],
        rubric={
            "hook_problem": "Does the speaker clearly articulate who feels the pain and why existing alternatives fail?",
            "solution_product": "Is the solution intuitive, differentiated, and defensible?",
            "traction_market": "Are metrics quantifiable (growth %, revenue, active users) rather than vague claims?",
            "business_model": "Is unit economics logic sound with clear margins?",
            "the_ask": "Is there an explicit monetary figure and milestone timeline?",
        },
        coaching_focus="Urgency, defensible unit economics, quantifiable traction, and specific capital allocation.",
    ),
    "hackathon_demo": PitchTemplate(
        id="hackathon_demo",
        title="Hackathon Demo",
        description="Demo a working project to judges within 2 minutes emphasizing innovation, working architecture, and real execution.",
        target_duration_seconds=120,
        sections=[
            TemplateSection(
                id="problem_statement",
                name="Problem Statement",
                description="Snappy problem definition in under 20 seconds.",
                weight=20.0,
                keywords=["problem", "why", "built", "frustration", "challenge", "need"],
            ),
            TemplateSection(
                id="live_demo",
                name="Live Working Demo",
                description="Core workflow walkthrough showing functional code and live UI.",
                weight=40.0,
                keywords=["demo", "app", "workflow", "feature", "live", "screen", "user", "works"],
            ),
            TemplateSection(
                id="tech_stack",
                name="Tech Stack & Architecture",
                description="APIs used, backend framework, data pipeline, and technical complexity.",
                weight=25.0,
                keywords=["architecture", "stack", "flutter", "fastapi", "api", "database", "model", "pipeline"],
            ),
            TemplateSection(
                id="future_scope",
                name="Future Scope & Impact",
                description="Next steps, scalability, and societal/developer impact.",
                weight=15.0,
                keywords=["future", "roadmap", "scale", "next steps", "impact", "production"],
            ),
        ],
        rubric={
            "problem_statement": "Is the problem stated quickly without wasting time on preamble?",
            "live_demo": "Does the speaker show the core user journey and prove the project works?",
            "tech_stack": "Does the speaker highlight non-trivial engineering decisions and integrations?",
            "future_scope": "Are realistic next steps outlined?",
        },
        coaching_focus="Fast pacing, crisp live demo narration, technical depth, and clean delivery.",
    ),
    "elevator_pitch": PitchTemplate(
        id="elevator_pitch",
        title="Elevator Pitch",
        description="Capture attention, deliver your value proposition, and secure a follow-up conversation in 60 seconds.",
        target_duration_seconds=60,
        sections=[
            TemplateSection(
                id="hook",
                name="Attention Grabber",
                description="First 10-second hook or surprising insight.",
                weight=25.0,
                keywords=["imagine", "did you know", "most", "every day", "billion", "secret"],
            ),
            TemplateSection(
                id="value_prop",
                name="Core Value Proposition",
                description="What you do, for whom, and the immediate transformation.",
                weight=35.0,
                keywords=["we help", "we build", "enables", "automatically", "solution", "transforms"],
            ),
            TemplateSection(
                id="differentiator",
                name="Differentiator",
                description="Why your approach beats standard alternatives.",
                weight=25.0,
                keywords=["unlike", "difference", "faster", "better", "cheaper", "unique", "only"],
            ),
            TemplateSection(
                id="cta",
                name="Call to Action",
                description="Clear request for a follow-up meeting, card exchange, or demo.",
                weight=15.0,
                keywords=["call", "meeting", "contact", "chat", "email", "coffee", "connect"],
            ),
        ],
        rubric={
            "hook": "Does the opening sentence spark immediate curiosity?",
            "value_prop": "Can a layman understand the offering in one sentence?",
            "differentiator": "Is the competitive edge sharply contrasted against alternatives?",
            "cta": "Is there a low-friction, immediate next step?",
        },
        coaching_focus="Punchy conciseness, memorable hook, crisp value articulation, and decisive CTA.",
    ),
    "viva": PitchTemplate(
        id="viva",
        title="Academic Viva / Defense",
        description="Defend research methodology, data integrity, experimental results, and critical limitations before examination committee.",
        target_duration_seconds=300,
        sections=[
            TemplateSection(
                id="research_gap",
                name="Objective & Literature Gap",
                description="Research problem, novelty, and theoretical background.",
                weight=20.0,
                keywords=["objective", "research", "literature", "hypothesis", "gap", "theory", "prior work"],
            ),
            TemplateSection(
                id="methodology",
                name="Methodology & System Design",
                description="Experimental design, mathematical model, datasets, and rigor.",
                weight=30.0,
                keywords=["methodology", "dataset", "algorithm", "parameters", "protocol", "architecture", "design"],
            ),
            TemplateSection(
                id="results_benchmarks",
                name="Empirical Results & Benchmarks",
                description="Comparative benchmarks, statistical significance, and error analysis.",
                weight=35.0,
                keywords=["results", "benchmark", "accuracy", "baseline", "p-value", "error", "metrics", "comparison"],
            ),
            TemplateSection(
                id="limitations_critique",
                name="Limitations & Future Work",
                description="Honest appraisal of constraints, edge cases, and extensions.",
                weight=15.0,
                keywords=["limitations", "constraints", "threats to validity", "future work", "scope"],
            ),
        ],
        rubric={
            "research_gap": "Is the scholarly gap and contribution clearly distinguished from prior literature?",
            "methodology": "Is the experimental protocol replicable and theoretically justified?",
            "results_benchmarks": "Are quantitative results backed by baseline comparisons and metric rigor?",
            "limitations_critique": "Does the candidate demonstrate academic honesty regarding scope and limitations?",
        },
        coaching_focus="Methodological rigor, baseline benchmarking, precision in terminology, and objective defense.",
    ),
}


def get_template(template_id: Optional[str]) -> Optional[PitchTemplate]:
    """Retrieves a pitch template by id from registry."""
    if not template_id:
        return None
    return TEMPLATE_REGISTRY.get(template_id.strip().lower())


def list_templates() -> List[PitchTemplate]:
    """Returns all available templates in the registry."""
    return list(TEMPLATE_REGISTRY.values())


def register_template(template: PitchTemplate) -> None:
    """Registers or updates a pitch template in the data-driven registry."""
    TEMPLATE_REGISTRY[template.id.strip().lower()] = template

