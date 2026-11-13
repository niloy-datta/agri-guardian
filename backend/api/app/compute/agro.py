"""Deterministic rainfall-onset, GDD, and historical-comparison science.

Every function here is pure: given the same daily observations and the
same explicit assumptions, it returns the same result, every time. No
FastAPI, no HTTP, no database, no LLM call appears anywhere in this
module - that boundary is deliberate (see `app/modules/advisory/service.py`,
the only caller, and the package docstring in `app/compute/__init__.py`).

A missing daily observation is represented as `None`, never `0.0`. A
window of days that includes a `None` cannot be evaluated honestly, so it
is skipped rather than silently treated as a dry (or zero-rainfall) day.
"""

from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from datetime import date, timedelta
from statistics import median

from scipy.stats import mannwhitneyu

DailySeries = Mapping[date, float | None]


# ============================================================
# Rainfall onset
# ============================================================


@dataclass(frozen=True, slots=True)
class OnsetDefinition:
    """The rainfall-onset rule being applied, carried on every result so a
    reader never has to guess which definition produced a number.

    Usable-rain onset: the first `window_days`-day period whose cumulative
    rainfall reaches `threshold_mm`, where that period is not immediately
    followed by a "false start" - a run of `dry_spell_max_days` or more
    fully dry (0.0 mm) consecutive days starting the day after the window
    ends. A day with no observation is never treated as dry: a gap right
    after a candidate window neither confirms nor breaks the dry-spell
    check, so the candidate is accepted rather than penalized for a data
    gap it cannot be blamed for.
    """

    window_days: int = 7
    threshold_mm: float = 20.0
    dry_spell_max_days: int = 7

    search_window_start_month_day: tuple[int, int] | None = None
    search_window_end_month_day: tuple[int, int] | None = None
    """Restricts which candidate windows are considered, by (month, day)
    within the series' own year - `None` (the default) searches the whole
    series, unchanged from this project's original behavior. Set this
    when "usable-rain onset" must mean onset within a specific season
    (e.g. the monsoon window relevant to a transplanting decision), not
    literally the first qualifying rain of the calendar year - see
    `app/modules/advisory/pilots/rajshahi_aman.py` for a case where this
    distinction mattered: Rajshahi's pre-monsoon (Feb-Apr) showers can
    otherwise qualify before the actual monsoon onset, producing a
    technically-correct but agronomically misleading result. This bound
    is this project's own analytical choice, never an agronomy citation."""


@dataclass(frozen=True, slots=True)
class OnsetResult:
    definition: OnsetDefinition
    found: bool
    onset_date: date | None = None
    onset_day_of_year: int | None = None
    window_cumulative_mm: float | None = None
    reason: str | None = None
    """Set when `found` is False: 'insufficient_data' (fewer usable days
    than one window) or 'no_qualifying_window' (every candidate window
    either missed the threshold or was disqualified as a false start)."""


def find_rainfall_onset(
    daily_precip_mm: DailySeries,
    *,
    definition: OnsetDefinition | None = None,
) -> OnsetResult:
    """Finds the first qualifying usable-rain onset in one series of daily
    precipitation observations (typically one calendar year).

    Candidates are evaluated in date order; the first one that both meets
    the threshold and survives the dry-spell check is returned. This is
    the earliest defensible onset under the stated definition, not
    necessarily the only qualifying window in the series.
    """
    onset_def = definition or OnsetDefinition()
    if onset_def.window_days < 1:
        raise ValueError("window_days must be at least 1")
    if onset_def.threshold_mm < 0:
        raise ValueError("threshold_mm must be non-negative")
    if onset_def.dry_spell_max_days < 0:
        raise ValueError("dry_spell_max_days must be non-negative")

    if not daily_precip_mm:
        return OnsetResult(definition=onset_def, found=False, reason="insufficient_data")

    sorted_dates = sorted(daily_precip_mm.keys())
    if len(sorted_dates) < onset_def.window_days:
        return OnsetResult(definition=onset_def, found=False, reason="insufficient_data")

    series_start, series_end = sorted_dates[0], sorted_dates[-1]

    candidate = series_start
    last_possible_start = series_end - timedelta(days=onset_def.window_days - 1)

    if onset_def.search_window_start_month_day is not None:
        year = series_start.year
        search_start = date(year, *onset_def.search_window_start_month_day)
        candidate = max(candidate, search_start)
    if onset_def.search_window_end_month_day is not None:
        year = series_start.year
        search_end = date(year, *onset_def.search_window_end_month_day)
        last_possible_start = min(last_possible_start, search_end)

    any_full_window_available = False

    while candidate <= last_possible_start:
        window_days = [candidate + timedelta(days=offset) for offset in range(onset_def.window_days)]
        window_values = [daily_precip_mm.get(day) for day in window_days]

        if any(value is None for value in window_values):
            candidate += timedelta(days=1)
            continue

        any_full_window_available = True
        cumulative = sum(value for value in window_values if value is not None)

        if cumulative >= onset_def.threshold_mm:
            window_end = window_days[-1]
            if not _is_false_start(
                daily_precip_mm,
                after=window_end,
                dry_spell_max_days=onset_def.dry_spell_max_days,
            ):
                return OnsetResult(
                    definition=onset_def,
                    found=True,
                    onset_date=candidate,
                    onset_day_of_year=candidate.timetuple().tm_yday,
                    window_cumulative_mm=cumulative,
                )

        candidate += timedelta(days=1)

    if not any_full_window_available:
        return OnsetResult(definition=onset_def, found=False, reason="insufficient_data")
    return OnsetResult(definition=onset_def, found=False, reason="no_qualifying_window")


def _is_false_start(
    daily_precip_mm: DailySeries,
    *,
    after: date,
    dry_spell_max_days: int,
) -> bool:
    """True only if `dry_spell_max_days` or more *observed* consecutive
    dry (0.0 mm) days immediately follow `after`. A day with no
    observation breaks the run of *confirmed* dry days without itself
    counting as dry - a gap cannot be used as evidence of a false start.
    """
    if dry_spell_max_days == 0:
        return False

    consecutive_dry = 0
    day = after + timedelta(days=1)
    for _ in range(dry_spell_max_days * 2):  # bounded probe past the threshold
        value = daily_precip_mm.get(day)
        if value is None:
            consecutive_dry = 0
        elif value <= 0.0:
            consecutive_dry += 1
            if consecutive_dry >= dry_spell_max_days:
                return True
        else:
            consecutive_dry = 0
        day += timedelta(days=1)
    return False


# ============================================================
# Growing degree days
# ============================================================


@dataclass(frozen=True, slots=True)
class GddResult:
    base_temperature_c: float
    daily_gdd_c: dict[date, float | None]
    cumulative_gdd_c: float
    days_with_data: int
    days_missing: int


def compute_daily_gdd(
    tmax_c: float | None, tmin_c: float | None, *, base_temperature_c: float
) -> float | None:
    """`max(((Tmax + Tmin) / 2) - base_temperature_c, 0)` for one day.

    Returns None (missing), never a fabricated 0.0, when either input is
    missing - a missing GDD day is not the same thing as a zero-GDD day.
    """
    if tmax_c is None or tmin_c is None:
        return None
    return max(((tmax_c + tmin_c) / 2.0) - base_temperature_c, 0.0)


def compute_gdd_series(
    daily_tmax_c: DailySeries,
    daily_tmin_c: DailySeries,
    *,
    base_temperature_c: float,
) -> GddResult:
    """Daily and cumulative GDD over the union of both series' dates.

    `base_temperature_c` is never defaulted here or anywhere in this
    module - it must be supplied by the caller as an explicit, documented
    agronomic assumption (see `app/modules/advisory/schemas.py`).
    """
    all_dates = sorted(set(daily_tmax_c.keys()) | set(daily_tmin_c.keys()))
    daily_gdd: dict[date, float | None] = {}
    for day in all_dates:
        daily_gdd[day] = compute_daily_gdd(
            daily_tmax_c.get(day), daily_tmin_c.get(day), base_temperature_c=base_temperature_c
        )

    present = [value for value in daily_gdd.values() if value is not None]
    return GddResult(
        base_temperature_c=base_temperature_c,
        daily_gdd_c=daily_gdd,
        cumulative_gdd_c=sum(present),
        days_with_data=len(present),
        days_missing=len(daily_gdd) - len(present),
    )


# ============================================================
# Historical period comparison
# ============================================================


@dataclass(frozen=True, slots=True)
class PeriodComparisonResult:
    reference_years_with_onset: list[int]
    recent_years_with_onset: list[int]
    reference_onset_days: list[int]
    """Day-of-year values, one per year in `reference_years_with_onset`."""
    recent_onset_days: list[int]
    reference_median_onset_doy: float | None
    recent_median_onset_doy: float | None
    shift_days: float | None
    """`recent_median - reference_median`. Positive = later onset in the
    recent period; negative = earlier. Never sign-flipped."""
    data_status: str
    """'ok', or 'insufficient_reference_data' / 'insufficient_recent_data'
    when a period has too few qualifying years to support a median."""


def onset_day_of_year_by_year(
    daily_precip_by_year: Mapping[int, DailySeries],
    *,
    definition: OnsetDefinition | None = None,
) -> dict[int, OnsetResult]:
    """Runs `find_rainfall_onset` independently for each year's series."""
    onset_def = definition or OnsetDefinition()
    return {
        year: find_rainfall_onset(series, definition=onset_def)
        for year, series in daily_precip_by_year.items()
    }


MIN_YEARS_FOR_MEDIAN = 3
"""Below this many qualifying years, a median is not a meaningful summary
of a period - the result is reported as insufficient data instead of a
number computed from one or two points."""


def compare_periods(
    onset_by_year: Mapping[int, OnsetResult],
    *,
    reference_years: Sequence[int],
    recent_years: Sequence[int],
) -> PeriodComparisonResult:
    reference_found = {
        year: onset_by_year[year]
        for year in reference_years
        if year in onset_by_year and onset_by_year[year].found
    }
    recent_found = {
        year: onset_by_year[year]
        for year in recent_years
        if year in onset_by_year and onset_by_year[year].found
    }

    reference_years_sorted = sorted(reference_found)
    recent_years_sorted = sorted(recent_found)
    # `found` guarantees `onset_day_of_year` is set, but the type checker
    # cannot see across that boolean, so the `is not None` filter both
    # narrows the type and documents the invariant explicitly.
    reference_days = [
        day
        for year in reference_years_sorted
        if (day := reference_found[year].onset_day_of_year) is not None
    ]
    recent_days = [
        day
        for year in recent_years_sorted
        if (day := recent_found[year].onset_day_of_year) is not None
    ]

    if len(reference_days) < MIN_YEARS_FOR_MEDIAN:
        return PeriodComparisonResult(
            reference_years_with_onset=reference_years_sorted,
            recent_years_with_onset=recent_years_sorted,
            reference_onset_days=reference_days,
            recent_onset_days=recent_days,
            reference_median_onset_doy=None,
            recent_median_onset_doy=None,
            shift_days=None,
            data_status="insufficient_reference_data",
        )
    if len(recent_days) < MIN_YEARS_FOR_MEDIAN:
        return PeriodComparisonResult(
            reference_years_with_onset=reference_years_sorted,
            recent_years_with_onset=recent_years_sorted,
            reference_onset_days=reference_days,
            recent_onset_days=recent_days,
            reference_median_onset_doy=median(reference_days),
            recent_median_onset_doy=None,
            shift_days=None,
            data_status="insufficient_recent_data",
        )

    reference_median = median(reference_days)
    recent_median = median(recent_days)
    return PeriodComparisonResult(
        reference_years_with_onset=reference_years_sorted,
        recent_years_with_onset=recent_years_sorted,
        reference_onset_days=reference_days,
        recent_onset_days=recent_days,
        reference_median_onset_doy=reference_median,
        recent_median_onset_doy=recent_median,
        shift_days=recent_median - reference_median,
        data_status="ok",
    )


# ============================================================
# Mann-Whitney U significance test
# ============================================================


@dataclass(frozen=True, slots=True)
class MannWhitneyResult:
    u_statistic: float | None
    p_value: float | None
    data_status: str
    """'ok', 'insufficient_data' (fewer than 2 observations in either
    sample - scipy cannot form a rank-sum comparison), or
    'degenerate_data' (scipy returned a non-finite statistic, e.g. every
    onset day-of-year within one or both samples is identical). A
    non-finite result is never passed through as a number: JSON has no
    NaN, so an un-guarded NaN silently becomes `null` on the wire and
    would be indistinguishable from an intentional "not computed" - both
    fields are set to None here instead, with a status that says why."""


def mann_whitney_shift_test(
    reference_onset_days: Sequence[int], recent_onset_days: Sequence[int]
) -> MannWhitneyResult:
    """Two-sided Mann-Whitney U test comparing the two periods' onset
    day-of-year distributions, via `scipy.stats.mannwhitneyu`.

    This reports whether the two samples' distributions differ under this
    test; it says nothing about *why* they differ and is not a causal
    claim about climate change or any other mechanism.
    """
    if len(reference_onset_days) < 2 or len(recent_onset_days) < 2:
        return MannWhitneyResult(u_statistic=None, p_value=None, data_status="insufficient_data")

    result = mannwhitneyu(recent_onset_days, reference_onset_days, alternative="two-sided")
    u_statistic, p_value = float(result.statistic), float(result.pvalue)
    if not (math.isfinite(u_statistic) and math.isfinite(p_value)):
        return MannWhitneyResult(u_statistic=None, p_value=None, data_status="degenerate_data")
    return MannWhitneyResult(u_statistic=u_statistic, p_value=p_value, data_status="ok")


# ============================================================
# Sensitivity analysis
# ============================================================


@dataclass(frozen=True, slots=True)
class SensitivityPoint:
    threshold_mm: float
    comparison: PeriodComparisonResult


@dataclass(frozen=True, slots=True)
class SensitivityResult:
    points: list[SensitivityPoint] = field(default_factory=list)


def sensitivity_analysis(
    daily_precip_by_year: Mapping[int, DailySeries],
    *,
    base_definition: OnsetDefinition,
    reference_years: Sequence[int],
    recent_years: Sequence[int],
    threshold_delta_mm: float = 5.0,
) -> SensitivityResult:
    """Re-runs the full onset -> period-comparison pipeline at
    `threshold_mm - delta`, `threshold_mm`, and `threshold_mm + delta` (a
    negative resulting threshold is clamped to 0), so a threshold-driven
    conclusion is visible rather than hidden behind one fixed choice.
    """
    thresholds = [
        max(base_definition.threshold_mm - threshold_delta_mm, 0.0),
        base_definition.threshold_mm,
        base_definition.threshold_mm + threshold_delta_mm,
    ]

    points: list[SensitivityPoint] = []
    for threshold in thresholds:
        definition = OnsetDefinition(
            window_days=base_definition.window_days,
            threshold_mm=threshold,
            dry_spell_max_days=base_definition.dry_spell_max_days,
        )
        onset_by_year = onset_day_of_year_by_year(daily_precip_by_year, definition=definition)
        comparison = compare_periods(
            onset_by_year, reference_years=reference_years, recent_years=recent_years
        )
        points.append(SensitivityPoint(threshold_mm=threshold, comparison=comparison))

    return SensitivityResult(points=points)
