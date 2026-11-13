"""Deterministic window-shift recommendation policy.

Pure functions only - no FastAPI, no HTTP, no database, no LLM (see
`app/compute/__init__.py`'s package boundary). This module decides
*whether* a shifted planting/transplanting window can be responsibly
returned, and by how much, from already-computed historical-comparison
and sensitivity results (`app/compute/agro.py`). It never recomputes
those statistics itself.

Conservative decision rule: an actionable shifted window is returned only
when the historical comparison succeeded (`data_status == "ok"`) AND the
sensitivity analysis agrees on direction at every threshold that produced
a result. Mann-Whitney significance is not part of this rule - it remains
evidence attached to the response, never an automatic "p < 0.05 means
act" trigger.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, timedelta

from app.compute.agro import PeriodComparisonResult, SensitivityResult

ROUNDING_RULE = (
    "Fractional shift_days is rounded to the nearest whole day, ties "
    "rounding away from zero (e.g. 2.5 -> 3, -2.5 -> -3)."
)


@dataclass(frozen=True, slots=True)
class BaselineWindow:
    """A verified agronomic calendar window. `window_type` is preserved
    exactly as sourced - this code never relabels a transplanting window
    as a sowing or planting window, or vice versa."""

    window_type: str
    """'sowing', 'transplanting', or 'broadcast planting' - whatever the
    source document actually calls it. Never genericized to "planting"
    if the source was more specific."""
    start_month_day: tuple[int, int]
    end_month_day: tuple[int, int]


@dataclass(frozen=True, slots=True)
class DateWindow:
    start: date
    end: date


@dataclass(frozen=True, slots=True)
class PlantingRecommendation:
    recommendation_status: str
    """'actionable' (a shifted window is returned), 'no_shift_supported'
    (historical comparison or sensitivity data is insufficient), or
    'sensitivity_unstable' (sensitivity thresholds disagree on the
    direction of the shift - see reason_codes)."""
    baseline_window: BaselineWindow
    recommended_window: DateWindow | None
    applied_shift_days: int | None
    reason_codes: list[str] = field(default_factory=list)


def round_shift_days(shift_days: float) -> int:
    """This project's one, documented rounding rule (`ROUNDING_RULE`):
    round-half-away-from-zero to the nearest whole day."""
    if shift_days >= 0:
        return math.floor(shift_days + 0.5)
    return -math.floor(-shift_days + 0.5)


def _shift_month_day(month_day: tuple[int, int], *, reference_year: int, shift_days: int) -> date:
    base = date(reference_year, month_day[0], month_day[1])
    return base + timedelta(days=shift_days)


def _sensitivity_shift_signs(sensitivity: SensitivityResult) -> set[int]:
    """The set of shift directions (-1, 0, +1) seen across every
    sensitivity point that actually produced a result. More than one
    distinct sign means the conclusion depends on which threshold is
    chosen - exactly the instability this policy must not paper over."""
    signs: set[int] = set()
    for point in sensitivity.points:
        comparison = point.comparison
        if comparison.data_status != "ok" or comparison.shift_days is None:
            continue
        if comparison.shift_days > 0:
            signs.add(1)
        elif comparison.shift_days < 0:
            signs.add(-1)
        else:
            signs.add(0)
    return signs


def evaluate_planting_recommendation(
    *,
    baseline_window: BaselineWindow,
    comparison: PeriodComparisonResult,
    sensitivity: SensitivityResult,
    reference_year_for_dates: int = 2001,
) -> PlantingRecommendation:
    """Applies the conservative decision rule described in this module's
    docstring. `reference_year_for_dates` is only a placeholder year used
    to do calendar arithmetic on a month/day window - it carries no
    meaning about which real year the recommendation applies to.
    """
    if comparison.data_status != "ok" or comparison.shift_days is None:
        return PlantingRecommendation(
            recommendation_status="no_shift_supported",
            baseline_window=baseline_window,
            recommended_window=None,
            applied_shift_days=None,
            reason_codes=[f"historical_comparison_{comparison.data_status}"],
        )

    shift_signs = _sensitivity_shift_signs(sensitivity)
    if len(shift_signs) > 1:
        return PlantingRecommendation(
            recommendation_status="sensitivity_unstable",
            baseline_window=baseline_window,
            recommended_window=None,
            applied_shift_days=None,
            reason_codes=["sensitivity_direction_contradictory"],
        )
    if not shift_signs:
        return PlantingRecommendation(
            recommendation_status="no_shift_supported",
            baseline_window=baseline_window,
            recommended_window=None,
            applied_shift_days=None,
            reason_codes=["sensitivity_insufficient_data"],
        )

    shift_days = round_shift_days(comparison.shift_days)
    recommended = DateWindow(
        start=_shift_month_day(
            baseline_window.start_month_day,
            reference_year=reference_year_for_dates,
            shift_days=shift_days,
        ),
        end=_shift_month_day(
            baseline_window.end_month_day,
            reference_year=reference_year_for_dates,
            shift_days=shift_days,
        ),
    )
    return PlantingRecommendation(
        recommendation_status="actionable",
        baseline_window=baseline_window,
        recommended_window=recommended,
        applied_shift_days=shift_days,
        reason_codes=["historical_comparison_ok", "sensitivity_direction_consistent"],
    )
