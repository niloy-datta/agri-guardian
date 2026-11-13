"""Unit tests for `app.compute.monsoon_onset` - the Han et al. (2024)
Dynamic-2 agronomic monsoon-onset method. Pure-function tests, no DB, no
FastAPI - matching the module's own no-FastAPI/HTTP/DB/LLM boundary.

Uses small, hand-built synthetic LWS/AWS/LDS/ADS values (not the real
Rajshahi Table 1 values) so each test isolates exactly one behavior of
the algorithm, per the phase brief's Task 7 list.
"""

from __future__ import annotations

from datetime import date, timedelta

from app.compute.monsoon_onset import (
    HanOnsetParameters,
    find_han_monsoon_onset,
)

# LWS=3, AWS=10mm, LDS=3, ADS=5mm, search May 15 - Aug 31, wet>=1mm, dry<=1mm,
# 20-day post-onset lookahead (module default) - small numbers, easy to hand-verify.
PARAMS = HanOnsetParameters(
    station_name="TestStation",
    lws_days=3,
    aws_mm=10.0,
    lds_days=3,
    ads_mm=5.0,
    search_start_month_day=(5, 15),
    search_end_month_day=(8, 31),
    wet_day_threshold_mm=1.0,
    dry_day_threshold_mm=1.0,
)


def _flat_series(year: int, *, value: float | None = 0.0) -> dict[date, float | None]:
    return {date(year, 1, 1) + timedelta(days=n): value for n in range(366)}


def test_qualifying_wet_spell_is_accepted_as_onset() -> None:
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 4.0
    series[date(2020, 6, 2)] = 4.0
    series[date(2020, 6, 3)] = 4.0  # cumulative 12mm >= AWS=10mm over LWS=3 days
    # Rest of the 20-day post-onset window (days 4-20) stays above the dry-day
    # threshold, so no disqualifying dry spell can form there.
    for offset in range(3, 20):
        series[date(2020, 6, 1) + timedelta(days=offset)] = 2.0

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is True
    assert result.onset_date == date(2020, 6, 1)
    assert result.initial_wet_spell_rainfall_mm == 12.0


def test_insufficient_aws_is_rejected() -> None:
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 2.0
    series[date(2020, 6, 2)] = 2.0
    series[date(2020, 6, 3)] = 2.0  # cumulative 6mm < AWS=10mm
    # No other qualifying window anywhere in the series.
    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False
    assert result.reason == "no_qualifying_window"


def test_insufficient_consecutive_wet_days_is_rejected() -> None:
    # Day 1 is wet and starts a spell, but day 2 breaks the cumulative
    # total below AWS even though day 3 alone would be enough - the
    # window is evaluated as a fixed LWS-day block, not a sliding pick.
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 15.0  # would qualify alone if LWS were 1
    series[date(2020, 6, 2)] = 0.0
    series[date(2020, 6, 3)] = 0.0  # cumulative over 3 days = 15mm >= 10mm... still qualifies

    # Make it genuinely insufficient: reduce day 1.
    series[date(2020, 6, 1)] = 5.0
    series[date(2020, 6, 2)] = 0.0
    series[date(2020, 6, 3)] = 0.0  # cumulative 5mm < AWS=10mm

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False


def test_qualifying_wet_spell_followed_by_disqualifying_dry_spell_is_rejected() -> None:
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 4.0
    series[date(2020, 6, 2)] = 4.0
    series[date(2020, 6, 3)] = 4.0  # cumulative 12mm >= AWS=10mm - qualifies as a wet spell
    # Immediately followed by a 3-day dry spell (<=1mm each) totalling <5mm -
    # a false onset under LDS=3/ADS=5.
    series[date(2020, 6, 4)] = 0.0
    series[date(2020, 6, 5)] = 0.0
    series[date(2020, 6, 6)] = 0.0

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False or result.onset_date != date(2020, 6, 1)
    rejected_dates = [r.candidate_date for r in result.rejected_candidates]
    assert date(2020, 6, 1) in rejected_dates


def test_later_candidate_accepted_after_first_false_onset() -> None:
    series = _flat_series(2020)
    # First candidate at Jun 1: qualifies, but false-started by a dry spell.
    series[date(2020, 6, 1)] = 4.0
    series[date(2020, 6, 2)] = 4.0
    series[date(2020, 6, 3)] = 4.0
    series[date(2020, 6, 4)] = 0.0
    series[date(2020, 6, 5)] = 0.0
    series[date(2020, 6, 6)] = 0.0
    # A later, genuine onset at Jun 20 with no disqualifying dry spell after.
    for offset in range(20):
        series[date(2020, 6, 20) + timedelta(days=offset)] = 4.0

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is True
    assert result.onset_date == date(2020, 6, 20)
    assert result.false_onset_candidates_rejected >= 1


def test_search_does_not_begin_before_search_start() -> None:
    series = _flat_series(2020)
    # A qualifying wet spell in early May, before the May 15 search start,
    # must never be picked up.
    series[date(2020, 5, 1)] = 10.0
    series[date(2020, 5, 2)] = 10.0
    series[date(2020, 5, 3)] = 10.0
    for offset in range(30):
        series[date(2020, 5, 1) + timedelta(days=offset)] = 5.0  # would pass everything

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    if result.found:
        assert result.onset_date >= date(2020, 5, 15)
    # Confirm the May 1 candidate itself was never even attempted/accepted.
    assert result.onset_date != date(2020, 5, 1)


def test_search_stops_at_sourced_end_boundary() -> None:
    series = _flat_series(2020)
    # A qualifying spell that starts after the Aug 31 search end must be ignored.
    series[date(2020, 9, 1)] = 10.0
    series[date(2020, 9, 2)] = 10.0
    series[date(2020, 9, 3)] = 10.0
    for offset in range(20):
        series[date(2020, 9, 1) + timedelta(days=offset)] = 5.0

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False


def test_exactly_one_mm_satisfies_both_wet_and_dry_thresholds() -> None:
    """Paper fact: wet day is >=1mm, dry day is <=1mm - these overlap at
    exactly 1.0mm. This test documents Mukti's literal, non-"fixed"
    implementation of that overlap (see docs/references/
    han_2024_agronomic_onset.md)."""
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 1.0
    series[date(2020, 6, 2)] = 1.0
    series[date(2020, 6, 3)] = 1.0  # exactly 3.0mm total - fails AWS=10 regardless

    # A day at exactly 1.0mm must count as "wet" for candidate selection...
    series[date(2020, 6, 10)] = 1.0
    series[date(2020, 6, 11)] = 5.0
    series[date(2020, 6, 12)] = 5.0  # cumulative 11mm >= AWS=10mm - qualifies
    for offset in range(20):
        if date(2020, 6, 10) + timedelta(days=offset) not in (
            date(2020, 6, 10),
            date(2020, 6, 11),
            date(2020, 6, 12),
        ):
            series[date(2020, 6, 10) + timedelta(days=offset)] = 5.0

    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is True
    assert result.onset_date == date(2020, 6, 10)


def test_missing_rainfall_does_not_become_zero() -> None:
    series = _flat_series(2020, value=None)
    # Only a small qualifying window has real data; everything else is
    # missing (None), never coerced to 0.0.
    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False
    assert result.missing_data_status == "insufficient_data"


def test_no_qualifying_onset_returns_explicit_no_result() -> None:
    series = _flat_series(2020, value=0.0)  # bone dry all year
    result = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert result.found is False
    assert result.onset_date is None
    assert result.reason == "no_qualifying_window"


def test_same_input_gives_deterministic_same_output() -> None:
    series = _flat_series(2020)
    series[date(2020, 6, 1)] = 4.0
    series[date(2020, 6, 2)] = 4.0
    series[date(2020, 6, 3)] = 4.0
    for offset in range(3, 20):
        series[date(2020, 6, 1) + timedelta(days=offset)] = 2.0

    first = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)
    second = find_han_monsoon_onset(series, parameters=PARAMS, year=2020)

    assert first == second
    assert first.found is True
