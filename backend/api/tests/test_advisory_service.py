"""Unit tests for AdvisoryService against synthetic, injected NASA POWER
evidence - no live NASA network call and no FastAPI app involved.

Every daily value used here is SYNTHETIC TEST DATA - NOT NASA
OBSERVATIONS, built deterministically so the same input always produces
the same result.
"""

import ast
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from app.integrations.nasa.client import NasaPowerProvenance, PowerDailyRecord, PowerDailyResponse
from app.integrations.nasa.power_cache import CacheLookupResult
from app.modules.advisory.schemas import PlantingWindowRequest
from app.modules.advisory.service import AdvisoryService

DEFAULT_PARAMETERS = ("PRECTOTCORR", "T2M_MAX", "T2M_MIN")


class FakeCache:
    """Stands in for NasaPowerCache: hands back a pre-built response
    instead of ever touching the network or a filesystem cache."""

    def __init__(self, response: PowerDailyResponse, source: str = "fixture") -> None:
        self._response = response
        self._source = source
        self.calls = 0

    async def get_daily_point(self, **_kwargs: object) -> CacheLookupResult:
        self.calls += 1
        return CacheLookupResult(response=self._response, source=self._source)


def _build_synthetic_response(
    *,
    start: date,
    end: date,
    onset_month_day_by_year: dict[int, tuple[int, int]],
    daily_rain_mm: float = 6.0,
    tmax_c: float = 30.0,
    tmin_c: float = 20.0,
) -> PowerDailyResponse:
    """One synthetic NASA POWER response covering `start..end`. From each
    year's onset date onward, precipitation is a constant `daily_rain_mm`;
    before it, 0.0. Temperature is constant so GDD has no missing days."""
    records: list[PowerDailyRecord] = []
    day = start
    while day <= end:
        onset = onset_month_day_by_year.get(day.year)
        precip = (
            daily_rain_mm
            if onset is not None and day >= date(day.year, onset[0], onset[1])
            else 0.0
        )
        records.append(
            PowerDailyRecord(date=day, precipitation_mm=precip, tmax_c=tmax_c, tmin_c=tmin_c)
        )
        day += timedelta(days=1)

    provenance = NasaPowerProvenance(
        provider="NASA POWER",
        dataset_id="SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS",
        source_url="file://synthetic-test-fixture",
        endpoint="/api/temporal/daily/point",
        community="AG",
        parameters=DEFAULT_PARAMETERS,
        latitude=24.36,
        longitude=90.35,
        start_date=start,
        end_date=end,
        time_standard="LST",
        retrieved_at=datetime(2020, 1, 1, tzinfo=UTC),
        units={"PRECTOTCORR": "mm/day", "T2M_MAX": "C", "T2M_MIN": "C"},
        raw_metadata={},
        data_mode="fixture",
    )
    return PowerDailyResponse(records=records, provenance=provenance, raw={})


def _base_request(**overrides: object) -> PlantingWindowRequest:
    defaults: dict[str, object] = {
        "latitude": 24.36,
        "longitude": 90.35,
        "start_year": 2001,
        "end_year": 2015,
        "reference_start_year": 2001,
        "reference_end_year": 2003,
        "recent_start_year": 2013,
        "recent_end_year": 2015,
        "base_temperature_c": 10.0,
    }
    defaults.update(overrides)
    return PlantingWindowRequest(**defaults)


REFERENCE_ONSETS = {2001: (4, 1), 2002: (4, 3), 2003: (3, 30)}
RECENT_ONSETS = {2013: (5, 1), 2014: (5, 4), 2015: (4, 29)}
"""Deliberately non-identical within each period - a Mann-Whitney test on
perfectly tied samples degenerates to a non-finite statistic, which
`mann_whitney_shift_test` correctly reports as 'degenerate_data' rather
than a fabricated number. These small day-to-day variations keep the
comparison meaningful, matching how real onset dates actually vary."""


async def test_deterministic_result_from_known_synthetic_evidence() -> None:
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={**REFERENCE_ONSETS, **RECENT_ONSETS},
    )
    request = _base_request()

    first = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(request)
    second = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(request)

    assert first.data_status == "ok"
    assert first.shift_days == second.shift_days
    assert first.reference_median_onset_doy == second.reference_median_onset_doy
    assert first.recent_median_onset_doy == second.recent_median_onset_doy
    assert first.mann_whitney_u == second.mann_whitney_u
    assert first.p_value == second.p_value
    # Non-degenerate (varied) onset days let Mann-Whitney actually compute
    # a finite statistic here, rather than the None the function returns
    # for a fully-tied sample (see `mann_whitney_shift_test`).
    assert first.mann_whitney_u is not None
    assert first.p_value is not None
    # May onset is later in the calendar than April onset.
    assert first.shift_days is not None and first.shift_days > 0


async def test_provenance_is_included() -> None:
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={**REFERENCE_ONSETS, **RECENT_ONSETS},
    )
    result = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(
        _base_request()
    )

    assert result.provenance.provider == "NASA POWER"
    assert result.provenance.data_mode == "fixture"
    assert result.provenance.source_url == "file://synthetic-test-fixture"
    assert "PRECTOTCORR" in result.provenance.parameters


async def test_assumptions_are_included() -> None:
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={**REFERENCE_ONSETS, **RECENT_ONSETS},
    )
    result = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(
        _base_request()
    )

    assert len(result.assumptions) >= 3
    joined = " ".join(result.assumptions)
    assert "20.0 mm" in joined  # default threshold echoed
    assert "10.0" in joined  # base temperature echoed
    assert "MEASURED/COMPUTED" in joined


async def test_sensitivity_is_included() -> None:
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={**REFERENCE_ONSETS, **RECENT_ONSETS},
    )
    result = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(
        _base_request()
    )

    thresholds = [point.threshold_mm for point in result.sensitivity]
    assert thresholds == [15.0, 20.0, 25.0]


async def test_insufficient_data_produces_honest_status_not_fake_shift() -> None:
    # Only one reference year ever has onset data - below MIN_YEARS_FOR_MEDIAN.
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={2001: (4, 1), 2013: (5, 1), 2014: (5, 1), 2015: (5, 1)},
    )
    result = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(
        _base_request()
    )

    assert result.data_status == "insufficient_reference_data"
    assert result.shift_days is None
    assert any("incomplete" in warning.lower() for warning in result.warnings)


async def test_missing_temperature_days_produce_warning_not_silent_zero() -> None:
    response = _build_synthetic_response(
        start=date(2001, 1, 1),
        end=date(2015, 12, 31),
        onset_month_day_by_year={**REFERENCE_ONSETS, **RECENT_ONSETS},
    )
    # Blank out one day's temperature entirely.
    records = list(response.records)
    records[0] = PowerDailyRecord(
        date=records[0].date, precipitation_mm=records[0].precipitation_mm, tmax_c=None, tmin_c=None
    )
    response = PowerDailyResponse(records=records, provenance=response.provenance, raw={})

    result = await AdvisoryService(cache=FakeCache(response)).compute_planting_window(
        _base_request()
    )

    assert result.gdd_summary.days_missing == 1
    assert any("missing temperature data" in warning for warning in result.warnings)


def test_no_llm_dependency_in_advisory_service_module() -> None:
    """Static check: no import in service.py references any LLM/AI
    provider package. Parsed via AST so this only inspects actual import
    statements, not comments or docstrings explaining the rule."""
    service_path = (
        Path(__file__).resolve().parents[1] / "app" / "modules" / "advisory" / "service.py"
    )
    tree = ast.parse(service_path.read_text(encoding="utf-8"))

    forbidden_substrings = ("openai", "anthropic", "langchain", "gpt", "llm")
    imported_modules: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported_modules.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported_modules.append(node.module)

    for module_name in imported_modules:
        lowered = module_name.lower()
        assert not any(forbidden in lowered for forbidden in forbidden_substrings), (
            f"advisory/service.py imports '{module_name}', which looks like an "
            "LLM/AI provider dependency - this phase must not call an LLM"
        )
