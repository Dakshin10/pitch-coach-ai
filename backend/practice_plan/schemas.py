"""
Pydantic schemas for Personalized Practice Plan (Feature 6).
"""
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class PracticeDrill(BaseModel):
    id: str = Field(..., description="Unique identifier for the drill")
    title: str = Field(..., description="Short actionable drill name")
    description: str = Field(..., description="Detailed instructions for the drill")
    target_metric: str = Field(..., description="Metric targeted: fillers | wpm | pauses | clarity | confidence")
    target_duration_seconds: int = Field(..., ge=15, le=300, description="Target drill duration")
    success_criteria: Dict[str, Any] = Field(..., description="Evaluation thresholds for completion")
    is_completed: bool = Field(default=False, description="Whether the user has completed this drill")
    completed_at: Optional[datetime] = None
    reason: str = Field(..., description="Why this drill was prescribed based on recent sessions")


class MetricDiagnosis(BaseModel):
    weakest_metric: str
    avg_wpm: float
    avg_fillers_per_100: float
    avg_pause_count: float
    sessions_analyzed: int
    score_trend: str  # improving | declining | steady | insufficient_data
    diagnostics_summary: str


class PracticePlanResponse(BaseModel):
    diagnosis: MetricDiagnosis
    drills: List[PracticeDrill]
    generated_at: datetime
    is_default_plan: bool = Field(
        default=False,
        description="True if user has no session history and was assigned default onboarding drills",
    )


class CompleteDrillRequest(BaseModel):
    drill_id: str
    session_id: Optional[str] = None
