"""
Groq API Cost & Latency Meter.
Tracks model, token counts, request duration, and estimated cost for all Groq calls.
"""
import logging
import time
from typing import Any, Dict, Optional

logger = logging.getLogger("groq_meter")

# Pricing per million tokens (Groq published rates, subject to updates)
MODEL_PRICING_PER_1M = {
    "llama-3.3-70b-versatile": {"input": 0.59, "output": 0.79},
    "llama-3.1-8b-instant": {"input": 0.05, "output": 0.08},
    "whisper-large-v3-turbo": {"per_minute": 0.0007},
    "llama-3.2-11b-vision-preview": {"input": 0.18, "output": 0.18},
}


class GroqCallMeter:
    @staticmethod
    def log_completion(
        model: str,
        duration_ms: float,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        call_type: str = "llm",
    ) -> Dict[str, Any]:
        """Calculates estimated cost and emits structured log for LLM completion."""
        rates = MODEL_PRICING_PER_1M.get(model, {"input": 0.50, "output": 0.80})
        cost_usd = (
            (prompt_tokens / 1_000_000) * rates.get("input", 0.0)
            + (completion_tokens / 1_000_000) * rates.get("output", 0.0)
        )

        log_data = {
            "type": call_type,
            "model": model,
            "duration_ms": round(duration_ms, 2),
            "tokens": {
                "prompt": prompt_tokens,
                "completion": completion_tokens,
                "total": prompt_tokens + completion_tokens,
            },
            "estimated_cost_usd": round(cost_usd, 6),
        }
        logger.info(
            "[GROQ_METER] %s | %s | %.1fms | tokens=%d | cost=$%.6f",
            call_type.upper(),
            model,
            duration_ms,
            prompt_tokens + completion_tokens,
            cost_usd,
        )
        return log_data

    @staticmethod
    def log_audio(
        model: str,
        duration_ms: float,
        audio_duration_seconds: float,
    ) -> Dict[str, Any]:
        """Calculates estimated cost and emits structured log for Whisper audio transcription."""
        audio_minutes = audio_duration_seconds / 60.0
        cost_usd = audio_minutes * MODEL_PRICING_PER_1M.get("whisper-large-v3-turbo", {}).get("per_minute", 0.0007)

        log_data = {
            "type": "audio_transcription",
            "model": model,
            "duration_ms": round(duration_ms, 2),
            "audio_duration_seconds": round(audio_duration_seconds, 2),
            "estimated_cost_usd": round(cost_usd, 6),
        }
        logger.info(
            "[GROQ_METER] AUDIO | %s | API latency=%.1fms | Audio=%.1fs | cost=$%.6f",
            model,
            duration_ms,
            audio_duration_seconds,
            cost_usd,
        )
        return log_data
