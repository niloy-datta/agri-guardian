"""Han et al. (2024) agronomic monsoon-onset method ("Dynamic 2").

Pure deterministic Python only - no FastAPI, no HTTP, no database, no LLM
(see `app/compute/__init__.py`'s package boundary). This module is a
separate, versioned method (`han_agronomic_onset_v1`) alongside the
project's original `usable_rain_v1` method in `agro.py` - it does not
replace or silently reinterpret that method's existing results.

Source: Han, E., Montes, C., Hussain, S.G., & Krupnik, T.J. (2024).
"Agronomic monsoon onset definitions to support planting decisions for
rainfed rice in Bangladesh." Climatic Change, 177(5), 77.
https://doi.org/10.1007/s10584-024-03736-z
See docs/references/han_2024_agronomic_onset.md for the full source
record, including which parts of this implementation are paper facts
versus Mukti's own implementation choices where the paper's prose is
silent (window boundary, wet/dry-day overlap at exactly 1mm, missing-data
handling).

Algorithm (paper, verbatim): "the first wet day from May 15th of the
first wet spell of LWS days receiving at least the amount of rainfall
AWS, without being followed by dry spell of LDS days receiving less
rainfall than ADS in the subsequent 20 days from the onset."
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from datetime import date, timedelta
from statistics import median

from app.compute.agro import MIN_YEARS_FOR_MEDIAN, PeriodComparisonResult

DailySeries = Mapping[date, float | None]

METHOD_ID = "han_agronomic_onset_v1"
METHOD_SOURCE_DOI = "10.1007/s10584-024-03736-z"

POST_ONSET_LOOKAHEAD_DAYS = 20
"""The paper's fixed "subsequent 20 days from the onset" window - not a
per-station parameter, so it is a module constant, not part of
`HanOnsetParameters`."""


@dataclass(frozen=True, slots=True)
class HanOnsetParameters:
    """One station's fitted Table 1 parameters, plus the search window and
    wet/dry-day thresholds this project applies alongside them. Every
    field here must trace to `docs/references/han_2024_agronomic_onset.md`
    - this dataclass carries no default values, so a caller can never
    accidentally run the algorithm with an unsourced parameter."""

    station_name: str
    lws_days: int
    """Length of the initial Wet Spell, in days."""
    aws_mm: float
    """Cumulative rainfall (mm) required during the initial wet spell."""
    lds_days: int
    """Length of a post-onset Dry Spell, in days, that disqualifies the
    candidate onset as a false start."""
    ads_mm: float
    """Rainfall ceiling (mm) for that dry spell to count as disqualifying."""
    search_start_month_day: tuple[int, int]
    search_end_month_day: tuple[int, int]
    wet_day_threshold_mm: float
    """A day qualifies as "wet" when rainfall >= this value."""
    dry_day_threshold_mm: float
    """A day qualifies as "dry" when rainfall <= this value. Note this can
    overlap with `wet_day_threshold_mm` at the boundary (paper fact - see
    source doc), and this implementation does not resolve that overlap."""
    post_onset_lookahead_days: int = POST_ONSET_LOOKAHEAD_DAYS


@dataclass(frozen=True, slots=True)
class RejectedCandidate:
    candidate_date: date
    reason: str
    """'false_onset_dry_spell' or 'insufficient_wet_spell_data' or
    'insufficient_post_onset_data'."""


@dataclass(frozen=True, slots=True)
class HanOnsetResult:
    method_id: str
    method_version: str
    parameters: HanOnsetParameters

    found: bool
    onset_date: date | None = None
    onset_day_of_year: int | None = None

    candidate_start_date: date | None = None
    """Same as `onset_date` when found - kept as a distinct field per
    Task 5's diagnostics requirement, since a future variant of this
    method could in principle accept a candidate different from its own
    start date."""
    initial_wet_spell_days: int | None = None
    initial_wet_spell_rainfall_mm: float | None = None

    post_onset_check_start: date | None = None
    post_onset_check_end: date | None = None

    false_onset_candidates_rejected: int = 0
    rejected_candidates: list[RejectedCandidate] = field(default_factory=list)

    missing_data_status: str = "ok"
    """'ok', or 'insufficient_data' when every candidate in the search
    window was disqualified only because of missing observations (never
    silently treated as 0mm) rather than a genuine no-qualifying-window
    result."""
    reason: str | None = None
    """Set when `found` is False and not already explained by
    `missing_data_status` - e.g. 'no_qualifying_window'."""


def _wet_spell_cumulative(
    daily_precip_mm: DailySeries, *, start: date, days: int
) -> float | None:
    """Cumulative rainfall over `days` consecutive days starting at
    `start`. Returns None if any day in the window is missing - a missing
    observation is never treated as a 0mm contribution."""
    total = 0.0
    for offset in range(days):
        value = daily_precip_mm.get(start + timedelta(days=offset))
        if value is None:
            return None
        total += value
    return total


def _has_disqualifying_dry_spell(
    daily_precip_mm: DailySeries,
    *,
    window_start: date,
    window_days: int,
    lds_days: int,
    ads_mm: float,
    dry_day_threshold_mm: float,
) -> bool | None:
    """True if any run of `lds_days` consecutive days within the
    `window_days`-day window starting at `window_start` are all dry-day
    qualifying AND their cumulative rainfall is < `ads_mm`. Returns None
    (not True/False) if the window cannot be fully evaluated because of
    missing data - the caller must not silently treat that as "no
    disqualifying dry spell found"."""
    if lds_days > window_days:
        return False

    saw_missing = False
    for run_start_offset in range(window_days - lds_days + 1):
        run_start = window_start + timedelta(days=run_start_offset)
        raw_values = [daily_precip_mm.get(run_start + timedelta(days=d)) for d in range(lds_days)]
        if any(value is None for value in raw_values):
            saw_missing = True
            continue
        run_values = [value for value in raw_values if value is not None]
        if all(value <= dry_day_threshold_mm for value in run_values) and sum(run_values) < ads_mm:
            return True

    return None if saw_missing else False


def find_han_monsoon_onset(
    daily_precip_mm: DailySeries,
    *,
    parameters: HanOnsetParameters,
    year: int,
) -> HanOnsetResult:
    """Finds the first Han et al. (2024) Dynamic-2 monsoon onset in one
    year's daily precipitation series, for one station's fitted
    parameters. `year` anchors the search window (`search_start_month_day`
    to `search_end_month_day`) to a specific calendar year - this
    function evaluates exactly one year at a time, matching
    `agro.find_rainfall_onset`'s per-year contract.
    """
    search_start = date(year, *parameters.search_start_month_day)
    search_end = date(year, *parameters.search_end_month_day)

    candidate = search_start
    rejected: list[RejectedCandidate] = []
    saw_missing_wet_spell = False
    saw_missing_post_onset = False

    while candidate <= search_end:
        candidate_value = daily_precip_mm.get(candidate)
        if candidate_value is None:
            saw_missing_wet_spell = True
            candidate += timedelta(days=1)
            continue
        if candidate_value < parameters.wet_day_threshold_mm:
            candidate += timedelta(days=1)
            continue

        wet_spell_total = _wet_spell_cumulative(
            daily_precip_mm, start=candidate, days=parameters.lws_days
        )
        if wet_spell_total is None:
            saw_missing_wet_spell = True
            rejected.append(
                RejectedCandidate(candidate_date=candidate, reason="insufficient_wet_spell_data")
            )
            candidate += timedelta(days=1)
            continue
        if wet_spell_total < parameters.aws_mm:
            candidate += timedelta(days=1)
            continue

        post_onset_start = candidate
        post_onset_end = candidate + timedelta(days=parameters.post_onset_lookahead_days - 1)
        has_false_onset = _has_disqualifying_dry_spell(
            daily_precip_mm,
            window_start=post_onset_start,
            window_days=parameters.post_onset_lookahead_days,
            lds_days=parameters.lds_days,
            ads_mm=parameters.ads_mm,
            dry_day_threshold_mm=parameters.dry_day_threshold_mm,
        )
        if has_false_onset is None:
            saw_missing_post_onset = True
            rejected.append(
                RejectedCandidate(candidate_date=candidate, reason="insufficient_post_onset_data")
            )
            candidate += timedelta(days=1)
            continue
        if has_false_onset:
            rejected.append(
                RejectedCandidate(candidate_date=candidate, reason="false_onset_dry_spell")
            )
            candidate += timedelta(days=1)
            continue

        return HanOnsetResult(
            method_id=METHOD_ID,
            method_version="1",
            parameters=parameters,
            found=True,
            onset_date=candidate,
            onset_day_of_year=candidate.timetuple().tm_yday,
            candidate_start_date=candidate,
            initial_wet_spell_days=parameters.lws_days,
            initial_wet_spell_rainfall_mm=wet_spell_total,
            post_onset_check_start=post_onset_start,
            post_onset_check_end=post_onset_end,
            false_onset_candidates_rejected=sum(
                1 for r in rejected if r.reason == "false_onset_dry_spell"
            ),
            rejected_candidates=rejected,
            missing_data_status="ok",
        )

    missing_status = (
        "insufficient_data" if (saw_missing_wet_spell or saw_missing_post_onset) else "ok"
    )
    return HanOnsetResult(
        method_id=METHOD_ID,
        method_version="1",
        parameters=parameters,
        found=False,
        false_onset_candidates_rejected=sum(
            1 for r in rejected if r.reason == "false_onset_dry_spell"
        ),
        rejected_candidates=rejected,
        missing_data_status=missing_status,
        reason="no_qualifying_window" if missing_status == "ok" else "insufficient_data",
    )


def han_onset_by_year(
    daily_precip_by_year: Mapping[int, DailySeries], *, parameters: HanOnsetParameters
) -> dict[int, HanOnsetResult]:
    """Runs `find_han_monsoon_onset` independently for each year's series -
    matching `agro.onset_day_of_year_by_year`'s contract exactly."""
    return {
        year: find_han_monsoon_onset(series, parameters=parameters, year=year)
        for year, series in daily_precip_by_year.items()
    }


def compare_han_periods(
    onset_by_year: Mapping[int, HanOnsetResult],
    *,
    reference_years: Sequence[int],
    recent_years: Sequence[int],
) -> PeriodComparisonResult:
    """The Han-method equivalent of `agro.compare_periods` - reuses that
    module's own `PeriodComparisonResult` shape and `MIN_YEARS_FOR_MEDIAN`
    threshold so both onset methods report period comparisons the exact
    same way, and so this logic exists in exactly one place (also used by
    `scripts/build_pilot_analysis.py`'s `build_han_analysis`)."""
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
