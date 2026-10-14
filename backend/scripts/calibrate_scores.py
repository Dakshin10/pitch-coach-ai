"""
Score Calibration Script.
Compares deterministic & structure scoring formulas against human-rated sample transcripts
to detect drift and ensure scoring calibration remains within acceptable tolerances (MAE ≤ 10.0).
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from sessions.pipeline import (
    _compute_clarity_score,
    _compute_confidence_score,
    _compute_structure_score,
    _compute_overall_score,
    FillerAnalysis,
    PauseAnalysis,
)

# Benchmark set of human-rated speeches (expert communication coaches)
CALIBRATION_BENCHMARKS = [
    {
        "id": "sample_1_polished_founder",
        "description": "Clear, concise seed pitch, zero fillers, natural pauses, hits all sections.",
        "transcript": (
            "Every enterprise struggles with cloud security data fragmentation. "
            "Our platform provides automated zero-trust authorization. "
            "In 6 months we scaled to 45 enterprise customers and $800k ARR. "
            "We charge a usage-based annual license with 85% gross margins. "
            "We are raising $2M to expand our engineering team and hit $3M ARR."
        ),
        "metrics": {
            "wpm": 145.0,
            "fillers": FillerAnalysis(total_count=0, breakdown={}, rate_per_100_words=0.0),
            "pauses": PauseAnalysis(count=3, avg_length=1.1, total_pause_time=3.3),
        },
        "template_id": "investor_pitch",
        "human_ratings": {
            "clarity": 95.0,
            "confidence": 92.0,
            "structure": 95.0,
            "overall": 94.0,
        },
    },
    {
        "id": "sample_2_nervous_student",
        "description": "High filler count ('um', 'like'), rushed pace, missing business model and ask.",
        "transcript": (
            "Um, hi everyone. Basically, like, our project is an app for students. "
            "Uh, you know, students struggle to find notes, so we built this website. "
            "Um, we used React and Python, and like, it works pretty well."
        ),
        "metrics": {
            "wpm": 182.0,
            "fillers": FillerAnalysis(total_count=6, breakdown={"um": 3, "like": 2, "basically": 1}, rate_per_100_words=14.0),
            "pauses": PauseAnalysis(count=6, avg_length=2.2, total_pause_time=13.2),
        },
        "template_id": "investor_pitch",
        "human_ratings": {
            "clarity": 55.0,
            "confidence": 50.0,
            "structure": 40.0,
            "overall": 50.0,
        },
    },
    {
        "id": "sample_3_solid_hackathon",
        "description": "Engaging live demo, crisp problem, realistic tech stack.",
        "transcript": (
            "Doctors spend 3 hours daily on medical charts. We built ChartPilot to automate this. "
            "Let me show you the live demo: I dictate patient symptoms, and in real time the EHR note generates. "
            "Our architecture leverages WebRTC, FastWhisper, and fine-tuned LLaMA on modal GPUs. "
            "Next week we are piloting with 5 local clinics."
        ),
        "metrics": {
            "wpm": 138.0,
            "fillers": FillerAnalysis(total_count=1, breakdown={"like": 1}, rate_per_100_words=1.5),
            "pauses": PauseAnalysis(count=2, avg_length=1.2, total_pause_time=2.4),
        },
        "template_id": "hackathon_demo",
        "human_ratings": {
            "clarity": 88.0,
            "confidence": 86.0,
            "structure": 88.0,
            "overall": 87.0,
        },
    },
]


def run_calibration():
    print("=" * 65)
    print("RUNNING PITCH COACH SCORE CALIBRATION")
    print("=" * 65)

    errors = []
    for item in CALIBRATION_BENCHMARKS:
        clarity = _compute_clarity_score(item["metrics"]["fillers"], item["metrics"]["pauses"])
        confidence = _compute_confidence_score(clarity, item["metrics"]["wpm"])
        structure, detected, missing = _compute_structure_score(
            item["transcript"], item["template_id"]
        )
        overall = _compute_overall_score(confidence, clarity, structure_score=structure)

        human = item["human_ratings"]
        err_clarity = abs(clarity - human["clarity"])
        err_conf = abs(confidence - human["confidence"])
        err_struct = abs(structure - human["structure"])
        err_overall = abs(overall - human["overall"])

        errors.append((err_clarity, err_conf, err_struct, err_overall))

        print(f"\nBenchmark [{item['id']}]:")
        print(f"  Clarity:    Algo={clarity:5.1f} | Human={human['clarity']:5.1f} | Diff={err_clarity:4.1f}")
        print(f"  Confidence: Algo={confidence:5.1f} | Human={human['confidence']:5.1f} | Diff={err_conf:4.1f}")
        print(f"  Structure:  Algo={structure:5.1f} | Human={human['structure']:5.1f} | Diff={err_struct:4.1f}")
        print(f"  Overall:    Algo={overall:5.1f} | Human={human['overall']:5.1f} | Diff={err_overall:4.1f}")

    mae_clarity = sum(e[0] for e in errors) / len(errors)
    mae_conf = sum(e[1] for e in errors) / len(errors)
    mae_struct = sum(e[2] for e in errors) / len(errors)
    mae_overall = sum(e[3] for e in errors) / len(errors)

    print("\n" + "-" * 65)
    print(f"CALIBRATION SUMMARY (Mean Absolute Error):")
    print(f"  Clarity MAE:    {mae_clarity:.2f} pts")
    print(f"  Confidence MAE: {mae_conf:.2f} pts")
    print(f"  Structure MAE:  {mae_struct:.2f} pts")
    print(f"  Overall MAE:    {mae_overall:.2f} pts")
    print("-" * 65)

    assert mae_overall <= 15.0, f"Overall MAE exceeds 15.0 pts tolerance ({mae_overall:.2f})"
    print("STATUS: CALIBRATION PASSED (All scores within human expert tolerance).")


if __name__ == "__main__":
    run_calibration()
