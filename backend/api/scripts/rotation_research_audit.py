"""Offline, reproducible audits for crop-rotation evidence and expert review.

This module never treats regional scenario outputs as observed field outcomes.
It does not download datasets, infer yields, or invent expert labels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def _read_json(path: Path) -> tuple[Any, str]:
    raw = path.read_bytes()
    return json.loads(raw), hashlib.sha256(raw).hexdigest()


def audit_recorded_runs(runs: dict[str, Any]) -> dict[str, Any]:
    """Describe a fixed scenario snapshot, without claiming predictive accuracy."""
    if not isinstance(runs, dict) or not runs:
        raise ValueError("Recorded runs must be a non-empty JSON object")

    status_counts: Counter[str] = Counter()
    provider_available: Counter[str] = Counter()
    district_names: set[str] = set()
    unknown_water_scenarios = 0
    insufficient_source_claims = 0
    total_scenarios = 0
    top_by_irrigation: dict[str, dict[str, tuple[str, ...]]] = defaultdict(dict)
    cases_missing_scenarios: list[str] = []

    for case_id, record in sorted(runs.items()):
        if not isinstance(record, dict):
            raise ValueError(f"{case_id}: scenario record must be an object")
        status = record.get("status")
        if status not in {"OK", "INSUFFICIENT_EVIDENCE"}:
            raise ValueError(f"{case_id}: unknown status {status!r}")
        status_counts[status] += 1
        district = record.get("location", {}).get("district")
        if isinstance(district, str) and district:
            district_names.add(district)
        scenarios = record.get("scenarios", [])
        if not isinstance(scenarios, list):
            raise ValueError(f"{case_id}: scenarios must be an array")
        if not scenarios:
            cases_missing_scenarios.append(case_id)
        total_scenarios += len(scenarios)

        for item in record.get("evidence", []):
            if item.get("status") == "AVAILABLE":
                provider_available[str(item.get("name", "unnamed"))] += 1

        for scenario in scenarios:
            if scenario.get("unknown_water_need"):
                unknown_water_scenarios += 1
            for claim in scenario.get("claims", []):
                if not str(claim.get("source", "")).strip():
                    insufficient_source_claims += 1

        if district and scenarios and "|" in case_id:
            _, irrigation = case_id.rsplit("|", 1)
            top_by_irrigation[district][irrigation] = tuple(scenarios[0].get("crops", []))

    paired_districts = [
        district for district, variants in top_by_irrigation.items()
        if "none" in variants and "full" in variants
    ]
    changed = sum(
        top_by_irrigation[d]["none"] != top_by_irrigation[d]["full"]
        for d in paired_districts
    )
    return {
        "evidence_level": "recorded_regional_scenarios_not_independent_field_validation",
        "recorded_cases": len(runs),
        "distinct_districts": len(district_names),
        "status_counts": dict(sorted(status_counts.items())),
        "scenario_count": total_scenarios,
        "scenarios_with_unknown_water_need": unknown_water_scenarios,
        "claims_missing_source": insufficient_source_claims,
        "cases_missing_scenarios": cases_missing_scenarios,
        "available_provider_case_counts": dict(sorted(provider_available.items())),
        "paired_irrigation_districts": len(paired_districts),
        "paired_districts_with_changed_top_rotation": changed,
        "limitations": [
            "Snapshot cases are not independent field validation or crop-yield observations.",
            "Recorded provider availability does not prove field-level measurement accuracy.",
            "Changes between irrigation settings do not establish agronomic improvement.",
        ],
    }


def _rotation_list(value: Any, field_name: str) -> list[tuple[str, ...]]:
    if not isinstance(value, list):
        raise ValueError(f"{field_name} must be an array")
    result: list[tuple[str, ...]] = []
    for rotation in value:
        if not isinstance(rotation, list) or not rotation or not all(
            isinstance(crop, str) and crop.strip() for crop in rotation
        ):
            raise ValueError(f"{field_name} entries must be non-empty crop arrays")
        result.append(tuple(rotation))
    return result


def evaluate_expert_reviews(payload: dict[str, Any]) -> dict[str, Any]:
    """Score expert-labeled scenarios; labels must be externally collected.

    Metrics describe agreement with independent expert opinions, NOT
    field-observed yield, soil improvement, or real-world model accuracy.
    """
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise ValueError("Expert review file requires schema_version = 1")
    rows = payload.get("reviews")
    if not isinstance(rows, list) or not rows:
        raise ValueError("No independent expert reviews supplied; metrics withheld")

    by_model: dict[str, list[tuple[list[tuple[str, ...]], list[tuple[str, ...]]]]] = defaultdict(list)
    identifiers: set[tuple[str, str]] = set()
    case_models: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("Every review must be an object")
        case_id = row.get("case_id")
        model = row.get("model")
        if not isinstance(case_id, str) or not case_id.strip():
            raise ValueError("Every review needs a non-empty case_id")
        if not isinstance(model, str) or not model.strip():
            raise ValueError("Every review needs a non-empty model")
        if not isinstance(row.get("district"), str) or not row["district"].strip():
            raise ValueError("Every review needs a district for spatial auditing")
        if not isinstance(row.get("season"), str) or not row["season"].strip():
            raise ValueError("Every review needs a season for temporal auditing")
        key = (case_id, model)
        if key in identifiers:
            raise ValueError(f"Duplicate case/model review: {key}")
        identifiers.add(key)
        case_models[case_id].add(model)
        proposed = _rotation_list(row.get("recommended_rotations"), "recommended_rotations")
        accepted = _rotation_list(row.get("expert_acceptable_rotations"), "expert_acceptable_rotations")
        by_model[model].append((proposed, accepted))

    models = sorted(by_model)
    common_cases = sorted(
        case_id for case_id, present in case_models.items() if len(present) == len(models)
    )
    results: dict[str, Any] = {}
    for model, records in sorted(by_model.items()):
        n = len(records)
        proposed_count = sum(bool(proposed) for proposed, _ in records)
        viable = sum(bool(accepted) for _, accepted in records)
        top1 = sum(bool(proposed and proposed[0] in accepted) for proposed, accepted in records)
        top3 = sum(bool(any(p in accepted for p in proposed[:3])) for proposed, accepted in records)
        unsupported = sum(bool(proposed and not accepted) for proposed, accepted in records)
        correct_abstain = sum(bool(not proposed and not accepted) for proposed, accepted in records)
        results[model] = {
            "reviewed_cases": n,
            "expert_viable_cases": viable,
            "decision_coverage": proposed_count / n,
            "top1_expert_agreement_on_viable_cases": top1 / viable if viable else None,
            "top3_expert_agreement_on_viable_cases": top3 / viable if viable else None,
            "recommendations_when_experts_found_no_safe_rotation": unsupported,
            "correct_abstentions_on_expert_no_option_cases": correct_abstain,
        }
    return {
        "evidence_level": "expert_opinion_agreement_not_observed_field_outcomes",
        "model_metrics": results,
        "paired_case_count": len(common_cases),
        "comparability_warning": (
            "Model metrics may use different cases. For paired comparison, "
            "restrict analysis to case IDs shared by every model."
        ),
        "limitations": [
            "Expert labels require independent collection and reviewer disagreement analysis.",
            "Do not interpret expert agreement as actual crop yield, profit or soil health.",
            "Report district-grouped and season-held-out results before generalization claims.",
        ],
    }


def main() -> None:
    root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--runs", type=Path,
        default=root / "docs" / "evidence" / "rotation_live_runs.json",
        help="Immutable recorded regional scenario JSON"
    )
    parser.add_argument(
        "--expert-reviews", type=Path, default=None,
        help="Optional independently collected review JSON (never fabricated)"
    )
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    runs, runs_sha256 = _read_json(args.runs)
    report: dict[str, Any] = {
        "recorded_runs_sha256": runs_sha256,
        "recorded_run_audit": audit_recorded_runs(runs),
    }
    if args.expert_reviews is not None:
        reviews, review_sha256 = _read_json(args.expert_reviews)
        report["expert_reviews_sha256"] = review_sha256
        report["expert_review_evaluation"] = evaluate_expert_reviews(reviews)
    else:
        report["expert_review_evaluation"] = {
            "status": "NOT_EVALUATED",
            "reason": "No independent expert labels were provided.",
        }

    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
