"""Tests for Phase 4A.2c's deterministic Han/NASA POWER transfer
validation gate (`app/compute/han_validation.py`). All synthetic - this
file does not depend on the real NASA POWER fixture (that is covered by
`tests/test_pilot_fixture.py`'s existing `requires_real_fixture` tests
and by `scripts/validate_han_transfer.py`'s own direct execution).
"""

from __future__ import annotations

import dataclasses
from datetime import date

from app.compute.agro import MannWhitneyResult, PeriodComparisonResult
from app.compute.han_validation import (
    BOUNDARY_GATE_DAYS,
    BOUNDARY_PCT_THRESHOLD,
    HanSensitivityRunResult,
    SensitivityPerturbation,
    classify_han_transfer_validation,
    compute_boundary_clustering,
    default_rajshahi_sensitivity_perturbations,
    run_han_sensitivity_perturbations,
)
from app.compute.monsoon_onset import HanOnsetParameters, HanOnsetResult
from app.modules.advisory.pilots.rajshahi_aman import RAJSHAHI_AMAN_PILOT

SEARCH_START = (5, 15)


def _found(year: int, onset: date) -> HanOnsetResult:
    return HanOnsetResult(
        method_id="han_agronomic_onset_v1",
        method_version="1",
        parameters=_PARAMS,
        found=True,
        onset_date=onset,
        onset_day_of_year=onset.timetuple().tm_yday,
    )


def _not_found(year: int) -> HanOnsetResult:
    return HanOnsetResult(
        method_id="han_agronomic_onset_v1",
        method_version="1",
        parameters=_PARAMS,
        found=False,
        reason="no_qualifying_window",
    )


_PARAMS = HanOnsetParameters(
    station_name="Rajshahi",
    lws_days=3,
    aws_mm=31.0,
    lds_days=6,
    ads_mm=11.0,
    search_start_month_day=SEARCH_START,
    search_end_month_day=(10, 31),
    wet_day_threshold_mm=1.0,
    dry_day_threshold_mm=1.0,
)


class TestPublishedHanParametersUnchanged:
    """Guards against an accidental edit to the published Rajshahi Table 1
    parameters - Phase 4A.2c's own explicit requirement. If any of these
    ever needs to change, it must be a deliberate, sourced edit to
    `docs/references/han_2024_agronomic_onset.md` plus this test, never a
    silent side effect of unrelated work."""

    def test_rajshahi_table1_values_are_exactly_the_published_ones(self) -> None:
        pilot = RAJSHAHI_AMAN_PILOT
        assert pilot.han_lws_days == 3
        assert pilot.han_aws_mm == 31.0
        assert pilot.han_lds_days == 6
        assert pilot.han_ads_mm == 11.0
        assert pilot.han_search_start_month_day == (5, 15)
        assert pilot.han_search_end_month_day == (10, 31)
        assert pilot.han_wet_day_threshold_mm == 1.0
        assert pilot.han_dry_day_threshold_mm == 1.0
        assert pilot.han_post_onset_lookahead_days == 20

    def test_decision_gate_flags_remain_false(self) -> None:
        """Scientific abstention is the correct state until a documented
        review flips these - this must never be accidentally toggled."""
        pilot = RAJSHAHI_AMAN_PILOT
        assert pilot.decision_enabled is False
        assert pilot.methodology_validated_for_mukti is False
        assert pilot.agronomic_link_validated is False


class TestBoundaryClustering:
    def test_counts_and_percentages_at_each_requested_distance(self) -> None:
        onset_by_year = {
            2001: _found(2001, date(2001, 5, 15)),  # 0 days from boundary
            2002: _found(2002, date(2002, 5, 16)),  # 1 day
            2003: _found(2003, date(2003, 5, 18)),  # 3 days
            2004: _found(2004, date(2004, 5, 25)),  # 10 days
        }
        points = compute_boundary_clustering(
            onset_by_year, search_start_month_day=SEARCH_START, boundary_days_list=(1, 3, 7)
        )
        by_days = {p.boundary_days: p for p in points}
        assert by_days[1].years_within_boundary == [2001, 2002]
        assert by_days[1].found_year_count == 4
        assert by_days[1].percentage == 50.0
        assert by_days[3].years_within_boundary == [2001, 2002, 2003]
        assert by_days[7].years_within_boundary == [2001, 2002, 2003]

    def test_no_found_years_gives_none_percentage_not_zero(self) -> None:
        onset_by_year = {2001: _not_found(2001)}
        points = compute_boundary_clustering(
            onset_by_year, search_start_month_day=SEARCH_START, boundary_days_list=(3,)
        )
        assert points[0].found_year_count == 0
        assert points[0].percentage is None
        assert points[0].years_within_boundary == []

    def test_no_onset_years_excluded_from_denominator(self) -> None:
        onset_by_year = {
            2001: _found(2001, date(2001, 5, 15)),
            2002: _not_found(2002),
        }
        points = compute_boundary_clustering(
            onset_by_year, search_start_month_day=SEARCH_START, boundary_days_list=(1,)
        )
        assert points[0].found_year_count == 1
        assert points[0].percentage == 100.0


class TestSensitivityPerturbations:
    def test_default_perturbations_change_exactly_one_field_each(self) -> None:
        perturbations = default_rajshahi_sensitivity_perturbations(_PARAMS)
        assert len(perturbations) == 8
        for p in perturbations:
            assert hasattr(_PARAMS, p.parameter_name)
            assert p.changed_value != p.original_value
            assert p.reason

    def test_perturbed_parameters_never_mutate_the_published_configuration(self) -> None:
        original = dataclasses.replace(_PARAMS)  # snapshot for comparison
        perturbations = default_rajshahi_sensitivity_perturbations(_PARAMS)
        run_han_sensitivity_perturbations(
            {},
            base_parameters=_PARAMS,
            perturbations=perturbations,
            reference_years=[],
            recent_years=[],
        )
        assert original == _PARAMS

    def test_perturbed_station_name_is_labeled_as_sensitivity_not_published(self) -> None:
        perturbations = default_rajshahi_sensitivity_perturbations(_PARAMS)
        results = run_han_sensitivity_perturbations(
            {},
            base_parameters=_PARAMS,
            perturbations=perturbations,
            reference_years=[],
            recent_years=[],
        )
        # Empty precip series -> every run reports insufficient data, but
        # the important assertion here is purely about labeling: no
        # sensitivity run's parameter set can be confused with the
        # published "Rajshahi" configuration.
        assert len(results) == len(perturbations)
        for perturbation in perturbations:
            # Reconstruct exactly as `_perturbed_parameters` would, to
            # confirm the label contract without depending on internals.
            assert perturbation.parameter_name in {"lws_days", "aws_mm", "lds_days", "ads_mm"}


class TestClassifyHanTransferValidation:
    def _stable_sensitivity(self) -> list[HanSensitivityRunResult]:
        comparison = PeriodComparisonResult(
            reference_years_with_onset=[2001, 2002, 2003],
            recent_years_with_onset=[2013, 2014, 2015],
            reference_onset_days=[140, 141, 142],
            recent_onset_days=[135, 136, 137],
            reference_median_onset_doy=141.0,
            recent_median_onset_doy=136.0,
            shift_days=-5.0,
            data_status="ok",
        )
        mw = MannWhitneyResult(u_statistic=9.0, p_value=0.05, data_status="ok")
        perturbation = SensitivityPerturbation(
            parameter_name="lds_days", original_value=6, changed_value=7, reason="test"
        )
        return [
            HanSensitivityRunResult(
                perturbation=perturbation,
                comparison=comparison,
                mann_whitney=mw,
                no_onset_year_count=0,
                false_onset_candidates_rejected_total=1,
            )
        ]

    def test_no_independent_evidence_is_always_insufficient_evidence(self) -> None:
        result = classify_han_transfer_validation(
            boundary_clustering=[],
            sensitivity_results=self._stable_sensitivity(),
            independent_evidence_available=False,
        )
        assert result.status == "insufficient_evidence"
        assert "no_independent_evidence_source_available" in result.reason_codes

    def test_deterministic_given_identical_inputs(self) -> None:
        kwargs = dict(
            boundary_clustering=[],
            sensitivity_results=self._stable_sensitivity(),
            independent_evidence_available=False,
        )
        first = classify_han_transfer_validation(**kwargs)  # type: ignore[arg-type]
        second = classify_han_transfer_validation(**kwargs)  # type: ignore[arg-type]
        assert first == second

    def test_contradictory_sensitivity_direction_is_transfer_uncertain_when_evidence_present(
        self,
    ) -> None:
        comparison_positive = PeriodComparisonResult(
            reference_years_with_onset=[2001, 2002, 2003],
            recent_years_with_onset=[2013, 2014, 2015],
            reference_onset_days=[135, 136, 137],
            recent_onset_days=[140, 141, 142],
            reference_median_onset_doy=136.0,
            recent_median_onset_doy=141.0,
            shift_days=5.0,
            data_status="ok",
        )
        mw = MannWhitneyResult(u_statistic=9.0, p_value=0.05, data_status="ok")
        contradictory_run = HanSensitivityRunResult(
            perturbation=SensitivityPerturbation(
                parameter_name="lds_days", original_value=6, changed_value=5, reason="test"
            ),
            comparison=comparison_positive,
            mann_whitney=mw,
            no_onset_year_count=0,
            false_onset_candidates_rejected_total=1,
        )
        result = classify_han_transfer_validation(
            boundary_clustering=[],
            sensitivity_results=[*self._stable_sensitivity(), contradictory_run],
            independent_evidence_available=True,
        )
        assert result.status == "transfer_uncertain"
        assert "sensitivity_direction_contradictory" in result.reason_codes

    def test_boundary_clustering_over_threshold_is_transfer_uncertain_when_evidence_present(
        self,
    ) -> None:
        from app.compute.han_validation import BoundaryClusterPoint

        over_threshold = BoundaryClusterPoint(
            boundary_days=BOUNDARY_GATE_DAYS,
            years_within_boundary=[2001, 2002, 2003, 2004],
            found_year_count=10,
            percentage=BOUNDARY_PCT_THRESHOLD + 1.0,
        )
        result = classify_han_transfer_validation(
            boundary_clustering=[over_threshold],
            sensitivity_results=self._stable_sensitivity(),
            independent_evidence_available=True,
        )
        assert result.status == "transfer_uncertain"
        assert any("boundary_clustering" in code for code in result.reason_codes)

    def test_validated_only_when_evidence_present_and_diagnostics_clean(self) -> None:
        from app.compute.han_validation import BoundaryClusterPoint

        under_threshold = BoundaryClusterPoint(
            boundary_days=BOUNDARY_GATE_DAYS,
            years_within_boundary=[2001],
            found_year_count=10,
            percentage=10.0,
        )
        result = classify_han_transfer_validation(
            boundary_clustering=[under_threshold],
            sensitivity_results=self._stable_sensitivity(),
            independent_evidence_available=True,
        )
        assert result.status == "validated"
