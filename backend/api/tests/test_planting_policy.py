"""Unit tests for `app.compute.planting_policy` - pure functions, no DB,
no HTTP, no fixtures needed. These construct `PeriodComparisonResult` /
`SensitivityResult` values directly rather than going through
`app.compute.agro`'s onset-finding pipeline, since the policy module never
recomputes those statistics itself.
"""

from __future__ import annotations

from datetime import date

import pytest

from app.compute.agro import PeriodComparisonResult, SensitivityPoint, SensitivityResult
from app.compute.planting_policy import (
    BaselineWindow,
    evaluate_planting_recommendation,
    round_shift_days,
)

BASELINE = BaselineWindow(
    window_type="transplanting",
    start_month_day=(6, 25),
    end_month_day=(8, 15),
)


def _comparison(*, shift_days: float | None, data_status: str = "ok") -> PeriodComparisonResult:
    return PeriodComparisonResult(
        reference_years_with_onset=[2001, 2002, 2003],
        recent_years_with_onset=[2013, 2014, 2015],
        reference_onset_days=[182, 183, 184],
        recent_onset_days=[191, 192, 193],
        reference_median_onset_doy=183.0,
        recent_median_onset_doy=192.0,
        shift_days=shift_days,
        data_status=data_status,
    )


def _sensitivity(*shift_values: float | None, data_statuses: list[str] | None = None) -> SensitivityResult:
    statuses = data_statuses or ["ok"] * len(shift_values)
    points = [
        SensitivityPoint(
            threshold_mm=15.0 + 5.0 * i,
            comparison=_comparison(shift_days=shift, data_status=status),
        )
        for i, (shift, status) in enumerate(zip(shift_values, statuses, strict=True))
    ]
    return SensitivityResult(points=points)


class TestRoundShiftDays:
    def test_rounds_down_below_half(self) -> None:
        assert round_shift_days(2.4) == 2

    def test_rounds_up_above_half(self) -> None:
        assert round_shift_days(2.6) == 3

    def test_half_rounds_away_from_zero_positive(self) -> None:
        assert round_shift_days(2.5) == 3

    def test_half_rounds_away_from_zero_negative(self) -> None:
        assert round_shift_days(-2.5) == -3

    def test_zero_stays_zero(self) -> None:
        assert round_shift_days(0.0) == 0


class TestEvaluatePlantingRecommendation:
    def test_actionable_shift_is_deterministic(self) -> None:
        comparison = _comparison(shift_days=9.0)
        sensitivity = _sensitivity(8.0, 9.0, 10.0)

        first = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )
        second = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert first == second
        assert first.recommendation_status == "actionable"
        assert first.applied_shift_days == 9
        assert first.recommended_window is not None
        assert first.recommended_window.start == date(2001, 7, 4)
        assert first.recommended_window.end == date(2001, 8, 24)

    def test_baseline_window_type_is_preserved_exactly(self) -> None:
        comparison = _comparison(shift_days=5.0)
        sensitivity = _sensitivity(5.0, 5.0, 5.0)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.baseline_window.window_type == "transplanting"

    def test_negative_shift_moves_window_earlier(self) -> None:
        comparison = _comparison(shift_days=-4.0)
        sensitivity = _sensitivity(-3.0, -4.0, -5.0)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "actionable"
        assert result.applied_shift_days == -4
        assert result.recommended_window is not None
        assert result.recommended_window.start == date(2001, 6, 21)
        assert result.recommended_window.end == date(2001, 8, 11)

    def test_no_actionable_recommendation_on_insufficient_reference_data(self) -> None:
        comparison = _comparison(shift_days=None, data_status="insufficient_reference_data")
        sensitivity = _sensitivity(None, None, None, data_statuses=["insufficient_reference_data"] * 3)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "no_shift_supported"
        assert result.recommended_window is None
        assert result.applied_shift_days is None
        assert "historical_comparison_insufficient_reference_data" in result.reason_codes

    def test_no_actionable_recommendation_on_insufficient_recent_data(self) -> None:
        comparison = _comparison(shift_days=None, data_status="insufficient_recent_data")
        sensitivity = _sensitivity(None, None, None, data_statuses=["insufficient_recent_data"] * 3)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "no_shift_supported"
        assert result.recommended_window is None

    def test_no_actionable_recommendation_when_sensitivity_has_no_qualifying_points(self) -> None:
        comparison = _comparison(shift_days=9.0)
        sensitivity = _sensitivity(None, None, None, data_statuses=["insufficient_recent_data"] * 3)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "no_shift_supported"
        assert result.recommended_window is None
        assert "sensitivity_insufficient_data" in result.reason_codes

    def test_sensitivity_unstable_when_direction_contradicts(self) -> None:
        comparison = _comparison(shift_days=9.0)
        sensitivity = _sensitivity(-2.0, 9.0, 10.0)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "sensitivity_unstable"
        assert result.recommended_window is None
        assert result.applied_shift_days is None
        assert "sensitivity_direction_contradictory" in result.reason_codes

    def test_zero_shift_at_one_threshold_counts_as_a_distinct_direction(self) -> None:
        """A zero-shift sensitivity point is its own sign bucket (neither
        + nor -), so mixing it with a nonzero-shift point at another
        threshold is exactly the kind of disagreement this policy must
        not paper over."""
        comparison = _comparison(shift_days=3.0)
        sensitivity = _sensitivity(0.0, 3.0, 4.0)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "sensitivity_unstable"
        assert result.recommended_window is None

    def test_all_thresholds_agreeing_on_positive_shift_is_actionable(self) -> None:
        comparison = _comparison(shift_days=3.0)
        sensitivity = _sensitivity(2.0, 3.0, 4.0)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.recommendation_status == "actionable"
        assert result.applied_shift_days == 3

    def test_mann_whitney_significance_is_not_part_of_the_decision(self) -> None:
        """The policy takes only `PeriodComparisonResult` and
        `SensitivityResult` - there is no p-value parameter at all, so a
        significant or non-significant Mann-Whitney result cannot change
        the outcome. This test documents that boundary structurally."""
        import inspect

        signature = inspect.signature(evaluate_planting_recommendation)
        assert "p_value" not in signature.parameters
        assert "mann_whitney" not in signature.parameters

    @pytest.mark.parametrize("shift_days", [0.4, 0.6, -0.4, -0.6])
    def test_rounding_is_applied_to_the_final_shift(self, shift_days: float) -> None:
        comparison = _comparison(shift_days=shift_days)
        sensitivity = _sensitivity(shift_days, shift_days, shift_days)

        result = evaluate_planting_recommendation(
            baseline_window=BASELINE, comparison=comparison, sensitivity=sensitivity
        )

        assert result.applied_shift_days == round_shift_days(shift_days)
