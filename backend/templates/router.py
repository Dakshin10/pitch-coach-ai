"""
FastAPI router for Pitch Templates.
"""
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Request
from limiter import limiter
from templates.registry import PitchTemplate, get_template, list_templates

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get(
    "",
    response_model=List[PitchTemplate],
    summary="List all available pitch templates (Investor, Hackathon, Elevator, Viva)",
)
@limiter.limit("30/minute")
async def list_templates_endpoint(request: Request):
    """Returns all data-driven pitch templates with section structures and rubrics."""
    return list_templates()


@router.get(
    "/{template_id}",
    response_model=PitchTemplate,
    summary="Get details and scoring rubric for a specific template",
)
@limiter.limit("30/minute")
async def get_template_endpoint(request: Request, template_id: str):
    """Retrieves specific pitch template by ID."""
    template = get_template(template_id)
    if not template:
        raise HTTPException(
            status_code=404,
            detail=f"Template '{template_id}' not found. Available: {', '.join([t.id for t in list_templates()])}",
        )
    return template
