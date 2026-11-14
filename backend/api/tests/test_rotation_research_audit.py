"""Offline verification of audit methodology; synthetic review rows are tests only."""

from __future__ import annotations

import pytest

from scripts.rotation_research_audit import audit_recorded_runs, evaluate_expert_reviews


def _runs():
    def case(district, irrigation, top):
        return {
            "status": "OK",
            "location": {"district": district},
            "evidence": [{"name": "BAMIS", "status": "AVAILABLE"}],
            "scenarios": [
                {"crops": top, "unknown_water_need": ["mustard"],
                 "claims": [{"source": "https://www.bamis.gov.bd/"}]}
            ],
        }
    return {
        "Rajshahi|none": case("Rajshahi", "none", ["aman_rice", "mustard"]),
        "Rajshahi|full": case("Rajshahi", "full", ["boro_rice", "mustard"]),
        "Sylhet|none": case("Sylhet", "none", ["aman_rice", "lentil"]),
        "Sylhet|full": case("Sylhet", "full", ["aman_rice", "lentil"]),
    }


def test_snapshot_audit_is_transparent_about_evidence_level():
    result = audit_recorded_runs(_runs())
    assert result["recorded_cases"] == 4
    assert result["distinct_districts"] == 2
    assert result["paired_irrigation_districts"] == 2
    assert result["paired_districts_with_changed_top_rotation"] == 1
    assert result["scenario_count"] == 4
    assert result["scenarios_with_unknown_water_need"] == 4
    assert result["claims_missing_source"] == 0
    assert "not_independent_field_validation" in result["evidence_level"]


def test_snapshot_rejects_invalid_records():
    with pytest.raises(ValueError):
        audit_recorded_runs({})
    with pytest.raises(ValueError):
        audit_recorded_runs({"one": {"status": "GUESS", "scenarios": []}})


def _review(case_id, model, proposals, accepted):
    return {
        "case_id": case_id, "district": "Rajshahi", "season": "aman_2026",
        "model": model,
        "recommended_rotations": proposals,
        "expert_acceptable_rotations": accepted,
    }


def test_expert_metrics_are_explicit_about_accepted_and_abstain_cases():
    data = {"schema_version": 1, "reviews": [
        _review("a", "fused", [["aman_rice", "mustard"]], [["aman_rice", "mustard"]]),
        _review("b", "fused", [], []),
        _review("c", "fused", [["boro_rice", "wheat"]], []),
    ]}
    metrics = evaluate_expert_reviews(data)["model_metrics"]["fused"]
    assert metrics["reviewed_cases"] == 3
    assert metrics["expert_viable_cases"] == 1
    assert metrics["decision_coverage"] == pytest.approx(2 / 3)
    assert metrics["top1_expert_agreement_on_viable_cases"] == 1.0
    assert metrics["recommendations_when_experts_found_no_safe_rotation"] == 1
    assert metrics["correct_abstentions_on_expert_no_option_cases"] == 1


def test_expert_metrics_do_not_invent_accuracy_without_viable_labels():
    data = {"schema_version": 1, "reviews": [_review("a", "calendar", [], [])]}
    metrics = evaluate_expert_reviews(data)["model_metrics"]["calendar"]
    assert metrics["top1_expert_agreement_on_viable_cases"] is None
    assert metrics["top3_expert_agreement_on_viable_cases"] is None


def test_expert_review_requires_real_rows_and_no_duplicates():
    with pytest.raises(ValueError, match="No independent"):
        evaluate_expert_reviews({"schema_version": 1, "reviews": []})
    row = _review("a", "fused", [], [])
    with pytest.raises(ValueError, match="Duplicate"):
        evaluate_expert_reviews({"schema_version": 1, "reviews": [row, row]})


def test_paired_case_count_requires_each_model():
    rows = [
        _review("a", "calendar", [], []),
        _review("a", "fused", [], []),
        _review("b", "calendar", [], []),
    ]
    result = evaluate_expert_reviews({"schema_version": 1, "reviews": rows})
    assert result["paired_case_count"] == 1
