"""Unit tests for the deterministic science in app/compute/agro.py.

No FastAPI import anywhere in this file - these are pure-function tests,
matching the module's own no-FastAPI/HTTP/DB/LLM boundary.
"""

from datetime import date, timedelta

from app.compute.agro import (
    OnsetDefinition,
    compare_periods,
    compute_daily_gdd,
    compute_gdd_series,
    find_rainfall_onset,
    mann_whitney_shift_test,
    onset_day_of_year_by_year,
    sensitivity_analysis,
)


def _daily_series(year: int, values_by_month_day: dict[tuple[int, int], float]) -> dict[date, float]:
    return {date(year, month, day): value for (month, day), value in values_by_month_day.items()}


# ============================================================
# Rainfall onset
# ============================================================


def test_onset_found_on_expected_date() -> None:
    # 3mm/day starting May 10 needs a full 7-day window to clear the
    # default 20mm threshold (7*3=21mm); any window with fewer than 7 wet
    # days falls short, so the earliest qualifying window - and therefore
    # the onset date - is exactly May 10. June stays wet, so nothing
    # disqualifies it as a false start.
    series: dict[date, float] = {}
    for day in range(1, 32):
        series[date(2020, 5, day)] = 3.0 if day >= 10 else 0.0
    for day in range(1, 31):
        series[date(2020, 6, day)] = 5.0

    result = find_rainfall_onset(series, definition=OnsetDefinition())

    assert result.found is True
    assert result.onset_date == date(2020, 5, 10)
    assert result.onset_day_of_year == date(2020, 5, 10).timetuple().tm_yday


def test_search_window_skips_a_qualifying_period_before_it() -> None:
    # A qualifying window exists in March, but the search is restricted to
    # May 1 - Sep 30 (e.g. to mean "monsoon onset", not "first rain of the
    # year") - the March window must be ignored and the May one found.
    series: dict[date, float] = {date(2020, 1, 1) + timedelta(days=n): 0.0 for n in range(366)}
    for day in range(10, 17):
        series[date(2020, 3, day)] = 3.0  # 7*3=21mm >= 20mm threshold
    for day in range(10, 17):
        series[date(2020, 5, day)] = 3.0
    for day in range(17, 31):
        series[date(2020, 5, day)] = 1.0  # keeps May onset from a false start

    definition = OnsetDefinition(
        search_window_start_month_day=(5, 1), search_window_end_month_day=(9, 30)
    )
    result = find_rainfall_onset(series, definition=definition)

    assert result.found is True
    assert result.onset_date == date(2020, 5, 10)


def test_search_window_with_no_qualifying_period_inside_it_reports_no_qualifying_window() -> None:
    series: dict[date, float] = {date(2020, 1, 1) + timedelta(days=n): 0.0 for n in range(366)}
    for day in range(10, 17):
        series[date(2020, 3, day)] = 3.0  # qualifies, but outside the search window

    definition = OnsetDefinition(
        search_window_start_month_day=(5, 1), search_window_end_month_day=(9, 30)
    )
    result = find_rainfall_onset(series, definition=definition)

    assert result.found is False


def test_no_search_window_preserves_original_whole_series_behavior() -> None:
    series: dict[date, float] = {}
    for day in range(1, 32):
        series[date(2020, 5, day)] = 3.0 if day >= 10 else 0.0
    for day in range(1, 31):
        series[date(2020, 6, day)] = 5.0

    result = find_rainfall_onset(series, definition=OnsetDefinition())

    assert result.found is True
    assert result.onset_date == date(2020, 5, 10)


def test_no_onset_returns_insufficient_or_no_result() -> None:
    # Every day bone dry for a full year: never reaches the threshold.
    series = {date(2020, 1, 1) + __import__("datetime").timedelta(days=n): 0.0 for n in range(365)}

    result = find_rainfall_onset(series)

    assert result.found is False
    assert result.reason == "no_qualifying_window"


def test_missing_rainfall_does_not_become_zero() -> None:
    # A window with a genuine gap must be skipped, not scored as if the
    # missing day contributed 0mm - construct a window that would clear
    # the threshold IF the gap were 0mm-but-present, and confirm it is
    # never reported as a valid onset from that window.
    series: dict[date, float | None] = {
        date(2020, 5, 1): 10.0,
        date(2020, 5, 2): None,  # gap
        date(2020, 5, 3): 10.0,
        date(2020, 5, 4): 5.0,
        date(2020, 5, 5): 5.0,
        date(2020, 5, 6): 5.0,
        date(2020, 5, 7): 5.0,
    }
    # No other data at all in the series - only this one ambiguous window.
    result = find_rainfall_onset(series)

    assert result.found is False
    assert result.reason in {"insufficient_data", "no_qualifying_window"}


def test_dry_spell_rule_disqualifies_false_start() -> None:
    definition = OnsetDefinition(window_days=7, threshold_mm=20.0, dry_spell_max_days=5)
    series: dict[date, float] = {}
    # False start: window May 1-7 clears 20mm (7*4=28mm), but May 8-14 is
    # a 7-day dry spell (> dry_spell_max_days=5), disqualifying it.
    for day in range(1, 8):
        series[date(2020, 5, day)] = 4.0
    for day in range(8, 15):
        series[date(2020, 5, day)] = 0.0
    # Genuine recovery from May 15 onward, sustained through June. The
    # earliest window not disqualified as a false start is May 13-19 (two
    # trailing dry days plus five wet ones = 20mm, immediately followed by
    # a wet day) - the algorithm reports the earliest defensible window
    # under the stated definition, not the first day rain resumed.
    for day in range(15, 32):
        series[date(2020, 5, day)] = 4.0
    for day in range(1, 31):
        series[date(2020, 6, day)] = 5.0

    result = find_rainfall_onset(series, definition=definition)

    assert result.found is True
    assert result.onset_date == date(2020, 5, 13)
    # And the disqualified May 1 false start is confirmed distinct from it.
    assert result.onset_date != date(2020, 5, 1)


# ============================================================
# GDD
# ============================================================


def test_gdd_daily_calculation() -> None:
    assert compute_daily_gdd(30.0, 20.0, base_temperature_c=10.0) == 15.0  # (30+20)/2 - 10
    # Clamped to zero when the mean is below base temperature.
    assert compute_daily_gdd(5.0, 0.0, base_temperature_c=10.0) == 0.0


def test_gdd_cumulative_calculation() -> None:
    tmax = _daily_series(2020, {(1, 1): 30.0, (1, 2): 32.0, (1, 3): 28.0})
    tmin = _daily_series(2020, {(1, 1): 20.0, (1, 2): 22.0, (1, 3): 18.0})

    result = compute_gdd_series(tmax, tmin, base_temperature_c=10.0)

    # Day 1: (30+20)/2-10=15, Day 2: (32+22)/2-10=17, Day 3: (28+18)/2-10=13
    assert result.cumulative_gdd_c == 45.0
    assert result.days_with_data == 3
    assert result.days_missing == 0
    assert result.base_temperature_c == 10.0


def test_gdd_missing_tmin_tmax_handling() -> None:
    tmax = _daily_series(2020, {(1, 1): 30.0, (1, 2): 32.0})
    tmin = _daily_series(2020, {(1, 1): 20.0})  # (1, 2) missing tmin

    result = compute_gdd_series(tmax, tmin, base_temperature_c=10.0)

    assert result.daily_gdd_c[date(2020, 1, 1)] == 15.0
    assert result.daily_gdd_c[date(2020, 1, 2)] is None
    assert result.days_with_data == 1
    assert result.days_missing == 1
    # The missing day must not be silently treated as 0 GDD - only the
    # single present day contributes to the cumulative total.
    assert result.cumulative_gdd_c == 15.0


# ============================================================
# Period comparison
# ============================================================


def _wet_year_series(year: int, onset_month: int, onset_day: int) -> dict[date, float]:
    series: dict[date, float] = {}
    for day in range(1, 366 if year % 4 == 0 else 365):
        current = date(year, 1, 1) + __import__("datetime").timedelta(days=day - 1)
        onset = date(year, onset_month, onset_day)
        series[current] = 6.0 if current >= onset else 0.0
    return series


def test_positive_median_shift_means_later_onset() -> None:
    onset_by_year = {}
    # Reference years onset early (day ~91, April 1); recent years onset
    # later (day ~121, May 1).
    for year in (2001, 2002, 2003):
        onset_by_year[year] = find_rainfall_onset(_wet_year_series(year, 4, 1))
    for year in (2013, 2014, 2015):
        onset_by_year[year] = find_rainfall_onset(_wet_year_series(year, 5, 1))

    comparison = compare_periods(
        onset_by_year, reference_years=[2001, 2002, 2003], recent_years=[2013, 2014, 2015]
    )

    assert comparison.data_status == "ok"
    assert comparison.shift_days is not None
    assert comparison.shift_days > 0


def test_negative_median_shift_means_earlier_onset() -> None:
    onset_by_year = {}
    for year in (2001, 2002, 2003):
        onset_by_year[year] = find_rainfall_onset(_wet_year_series(year, 5, 1))
    for year in (2013, 2014, 2015):
        onset_by_year[year] = find_rainfall_onset(_wet_year_series(year, 4, 1))

    comparison = compare_periods(
        onset_by_year, reference_years=[2001, 2002, 2003], recent_years=[2013, 2014, 2015]
    )

    assert comparison.shift_days is not None
    assert comparison.shift_days < 0


def test_insufficient_years_handled_honestly() -> None:
    onset_by_year = {
        2001: find_rainfall_onset(_wet_year_series(2001, 4, 1)),
        2013: find_rainfall_onset(_wet_year_series(2013, 5, 1)),
    }

    comparison = compare_periods(onset_by_year, reference_years=[2001], recent_years=[2013])

    assert comparison.data_status == "insufficient_reference_data"
    assert comparison.shift_days is None
    assert comparison.reference_median_onset_doy is None


# ============================================================
# Mann-Whitney
# ============================================================


def test_mann_whitney_output_is_deterministic() -> None:
    reference_days = [90, 92, 88, 95, 91]
    recent_days = [120, 118, 122, 125, 119]

    first = mann_whitney_shift_test(reference_days, recent_days)
    second = mann_whitney_shift_test(reference_days, recent_days)

    assert first.data_status == "ok"
    assert first.u_statistic == second.u_statistic
    assert first.p_value == second.p_value


def test_mann_whitney_insufficient_samples() -> None:
    result = mann_whitney_shift_test([90], [120])
    assert result.data_status == "insufficient_data"
    assert result.u_statistic is None
    assert result.p_value is None


# ============================================================
# Sensitivity
# ============================================================


def test_sensitivity_includes_threshold_minus_base_plus() -> None:
    precip_by_year = {
        2001: _wet_year_series(2001, 4, 1),
        2002: _wet_year_series(2002, 4, 5),
        2003: _wet_year_series(2003, 4, 10),
        2013: _wet_year_series(2013, 5, 1),
        2014: _wet_year_series(2014, 5, 5),
        2015: _wet_year_series(2015, 5, 10),
    }
    definition = OnsetDefinition(window_days=7, threshold_mm=20.0, dry_spell_max_days=7)

    result = sensitivity_analysis(
        precip_by_year,
        base_definition=definition,
        reference_years=[2001, 2002, 2003],
        recent_years=[2013, 2014, 2015],
        threshold_delta_mm=5.0,
    )

    thresholds = [point.threshold_mm for point in result.points]
    assert thresholds == [15.0, 20.0, 25.0]
    for point in result.points:
        assert point.comparison.data_status == "ok"


def test_onset_by_year_helper_runs_each_year_independently() -> None:
    precip_by_year = {
        2001: _wet_year_series(2001, 4, 1),
        2002: {},  # no data at all this year
    }

    results = onset_day_of_year_by_year(precip_by_year)

    assert results[2001].found is True
    assert results[2002].found is False
    assert results[2002].reason == "insufficient_data"
