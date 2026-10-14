"""
Pytest suite for Vocal Delivery Analysis (Feature 7).
Validates monotone detection, expressive pitch scoring, energy curve resolution,
confidence score integration, and processing latency benchmarking.
"""
import math
import struct
import time
import wave
import io
import pytest

from audio_analysis.vocal_delivery import (
    VocalDeliveryMetrics,
    analyze_vocal_delivery,
)
from sessions.pipeline import _compute_confidence_score


def _generate_synthetic_wav(
    duration_s: float = 3.0,
    sample_rate: int = 16000,
    is_expressive: bool = False,
    volume_amplitude: int = 12000,
) -> bytes:
    """Generates synthetic 16-bit PCM WAV audio."""
    total_samples = int(duration_s * sample_rate)
    samples = []
    for i in range(total_samples):
        t = i / float(sample_rate)
        if is_expressive:
            # Frequency modulates between 120Hz and 220Hz
            f0 = 150.0 + 50.0 * math.sin(2 * math.pi * 1.5 * t)
        else:
            # Perfectly flat 150Hz monotone
            f0 = 150.0
        val = int(volume_amplitude * math.sin(2 * math.pi * f0 * t))
        samples.append(max(-32767, min(32767, val)))

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    return buf.getvalue()


class TestVocalDeliveryAnalysis:
    def test_flat_monotone_sample_scores_low_variation(self):
        """Flat, single-pitch audio scores low pitch variation and flags is_monotone."""
        wav_bytes = _generate_synthetic_wav(duration_s=3.0, is_expressive=False)
        metrics = analyze_vocal_delivery(wav_bytes)

        assert metrics.pitch_std_hz < 10.0
        assert metrics.pitch_variation_score < 35.0
        assert metrics.is_monotone is True

    def test_expressive_sample_scores_high_variation(self):
        """Dynamic modulating speech scores high variation and flags is_monotone=False."""
        wav_bytes = _generate_synthetic_wav(duration_s=3.0, is_expressive=True)
        metrics = analyze_vocal_delivery(wav_bytes)

        assert metrics.pitch_std_hz > 25.0
        assert metrics.pitch_variation_score > 70.0
        assert metrics.is_monotone is False

    def test_energy_curve_downsampled_to_target_points(self):
        """Energy curve produces exactly 30 normalized points within [0.0, 1.0]."""
        wav_bytes = _generate_synthetic_wav(duration_s=4.0, is_expressive=True)
        metrics = analyze_vocal_delivery(wav_bytes, target_curve_points=30)

        assert len(metrics.energy_curve) == 30
        for val in metrics.energy_curve:
            assert 0.0 <= val <= 1.0
        # Energy should have non-zero peaks
        assert max(metrics.energy_curve) > 0.5

    def test_vocal_delivery_latency_under_150ms(self):
        """Latency benchmarking confirms analysis completes well under 150ms target."""
        # 5 seconds of audio (~80,000 samples)
        wav_bytes = _generate_synthetic_wav(duration_s=5.0, is_expressive=True)
        t0 = time.perf_counter()
        metrics = analyze_vocal_delivery(wav_bytes)
        total_time_ms = (time.perf_counter() - t0) * 1000.0

        assert total_time_ms < 150.0
        assert metrics.latency_ms > 0.0
        print(f"Added Vocal Delivery Latency: {metrics.latency_ms:.2f} ms")

    def test_confidence_score_incorporates_vocal_delivery(self):
        """Confidence score changes meaningfully between flat and expressive delivery."""
        clarity = 85.0
        wpm = 140.0  # optimal WPM -> 100 score

        monotone_delivery = VocalDeliveryMetrics(
            pitch_variation_score=20.0,
            volume_consistency_score=60.0,
        )
        expressive_delivery = VocalDeliveryMetrics(
            pitch_variation_score=90.0,
            volume_consistency_score=85.0,
        )

        conf_monotone = _compute_confidence_score(clarity, wpm, delivery_metrics=monotone_delivery)
        conf_expressive = _compute_confidence_score(clarity, wpm, delivery_metrics=expressive_delivery)

        # Expressive delivery score is significantly higher than monotone
        assert conf_expressive > conf_monotone + 10.0

    def test_invalid_or_empty_audio_handles_gracefully(self):
        """Empty or corrupt audio inputs gracefully return sensible defaults without crashing."""
        empty_metrics = analyze_vocal_delivery(b"")
        assert len(empty_metrics.energy_curve) == 30
        assert 0.0 <= empty_metrics.pitch_variation_score <= 100.0
        assert empty_metrics.latency_ms >= 0.0

        corrupt_metrics = analyze_vocal_delivery(b"NOT_A_VALID_WAV_HEADER_DATA")
        assert len(corrupt_metrics.energy_curve) == 30
        assert 0.0 <= corrupt_metrics.pitch_variation_score <= 100.0
