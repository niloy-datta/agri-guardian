#!/usr/bin/env python
"""Generates the Rajshahi Aman pilot's machine-readable analysis artifact.

This script never hand-types a calculated value. It:

1. Reads the REAL, manifest-verified NASA POWER fixture for the pilot's
   sourced coordinate via `NasaPowerCache` in offline mode - the same
   integrity check (`verify_fixture_entry`) the running API uses, so a
   tampered or unmanifested fixture is refused here too.
2. Runs the existing deterministic functions in `app/compute/agro.py` -
   this script does not reimplement or approximate any statistic.
3. Writes `demo_fixtures/analysis/rajshahi_aman_analysis.json`.

If the fixture is missing or fails verification, this script refuses to
write anything and reports why - it never falls back to synthetic data
dressed up as a real analysis.

Usage (from `backend/api`):

    python scripts/build_pilot_analysis.py

Reproducing this artifact from scratch: run
`scripts/fetch_power_fixture.py` for the pilot's exact coordinate/period
(see `app/modules/advisory/pilots/rajshahi_aman.py`), then run this
script - the output must be byte-for-byte identical (`generated_at`
aside) given the same fixture, since every function it calls is pure.
"""

from __future__ import annotations

import asyncio
import json
import sys
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_API_ROOT = SCRIPT_DIR.parent
REPO_ROOT = BACKEND_API_ROOT.parent.parent
sys.path.insert(0, str(BACKEND_API_ROOT))

from app.compute.agro import (  # noqa: E402
    OnsetDefinition,
    compare_periods,
    mann_whitney_shift_test,
    onset_day_of_year_by_year,
    sensitivity_analysis,
)
from app.compute.monsoon_onset import (  # noqa: E402
    METHOD_ID,
    METHOD_SOURCE_DOI,
    HanOnsetParameters,
    compare_han_periods,
    han_onset_by_year,
)
from app.integrations.nasa.client import (  # noqa: E402
    DEFAULT_PARAMETERS,
    NasaPowerClient,
    PowerDailyResponse,
)
from app.integrations.nasa.power_cache import (  # noqa: E402
    NasaEvidenceIntegrityError,
    NasaPowerCache,
    NasaPowerUnavailableOfflineError,
)
from app.modules.advisory.pilots.rajshahi_aman import (  # noqa: E402
    RAJSHAHI_AMAN_PILOT,
    RajshahiAmanPilot,
)

ANALYSIS_VERSION = "1"
HAN_ANALYSIS_VERSION = "1"
SENSITIVITY_THRESHOLD_DELTA_MM = 5.0

DEFAULT_FIXTURE_DIR = REPO_ROOT / "demo_fixtures" / "nasa_power"
DEFAULT_OUTPUT_PATH = REPO_ROOT / "demo_fixtures" / "analysis" / "rajshahi_aman_analysis.json"
DEFAULT_HAN_OUTPUT_PATH = (
    REPO_ROOT / "demo_fixtures" / "analysis" / "rajshahi_aman_han_2024_analysis.json"
)


def _group_by_year(
    records: list[Any], *, field: str, start_year: int, end_year: int
) -> dict[int, dict[date, float | None]]:
    grouped: dict[int, dict[date, float | None]] = {
        year: {} for year in range(start_year, end_year + 1)
    }
    for record in records:
        year = record.date.year
        if year in grouped:
            grouped[year][record.date] = getattr(record, field)
    return grouped


async def _load_real_fixture_response(
    pilot: RajshahiAmanPilot, *, fixture_dir: Path
) -> PowerDailyResponse:
    """Loads the real, manifest-verified NASA POWER fixture for the
    pilot's coordinate/period - shared by both `build_analysis` (the
    original `usable_rain_v1` method) and `build_han_analysis` (the new
    `han_agronomic_onset_v1` method), so both read the exact same
    evidence via the exact same integrity check."""
    client = NasaPowerClient(base_url="https://power.larc.nasa.gov", timeout_seconds=30.0)
    try:
        cache = NasaPowerCache(
            client=client,
            # An empty, non-fixture directory: this must be served from
            # the committed fixture, never from a stray cache entry.
            cache_dir=fixture_dir.parent / ".analysis_scratch_cache",
            fixture_dir=fixture_dir,
            offline=True,
        )
        lookup = await cache.get_daily_point(
            latitude=pilot.latitude,
            longitude=pilot.longitude,
            start=date(pilot.reference_start_year, 1, 1),
            end=date(pilot.recent_end_year, 12, 31),
            parameters=DEFAULT_PARAMETERS,
            community="AG",
        )
    finally:
        await client.aclose()

    if lookup.source != "fixture":
        raise NasaEvidenceIntegrityError(
            f"Expected the real committed fixture, got source={lookup.source!r} - "
            "refusing to build an analysis artifact from anything else."
        )
    return lookup.response


async def build_analysis(
    pilot: RajshahiAmanPilot, *, fixture_dir: Path
) -> dict[str, Any]:
    response = await _load_real_fixture_response(pilot, fixture_dir=fixture_dir)
    provenance = response.provenance

    precip_by_year = _group_by_year(
        response.records,
        field="precipitation_mm",
        start_year=pilot.reference_start_year,
        end_year=pilot.recent_end_year,
    )

    definition = OnsetDefinition(
        window_days=pilot.rain_window_days,
        threshold_mm=pilot.rain_threshold_mm,
        dry_spell_max_days=pilot.dry_spell_max_days,
    )
    onset_by_year = onset_day_of_year_by_year(precip_by_year, definition=definition)

    reference_years = range(pilot.reference_start_year, pilot.reference_end_year + 1)
    recent_years = range(pilot.recent_start_year, pilot.recent_end_year + 1)

    comparison = compare_periods(
        onset_by_year, reference_years=reference_years, recent_years=recent_years
    )
    mann_whitney = mann_whitney_shift_test(
        comparison.reference_onset_days, comparison.recent_onset_days
    )
    sensitivity = sensitivity_analysis(
        precip_by_year,
        base_definition=definition,
        reference_years=reference_years,
        recent_years=recent_years,
        threshold_delta_mm=SENSITIVITY_THRESHOLD_DELTA_MM,
    )

    total_days = sum(len(series) for series in precip_by_year.values())
    missing_days = sum(
        1
        for series in precip_by_year.values()
        for value in series.values()
        if value is None
    )

    yearly_onset: dict[str, dict[str, Any]] = {}
    for year in sorted(onset_by_year):
        result = onset_by_year[year]
        yearly_onset[str(year)] = {
            "found": result.found,
            "onset_date": result.onset_date.isoformat() if result.onset_date else None,
            "onset_day_of_year": result.onset_day_of_year,
            "window_cumulative_mm": result.window_cumulative_mm,
            "reason": result.reason,
        }

    return {
        "pilot_id": pilot.pilot_id,
        "analysis_version": ANALYSIS_VERSION,
        "source_fixture_sha256": provenance.fixture_sha256,
        "source_fixture_path": provenance.local_evidence_path,
        "nasa_source_url": provenance.source_url,
        "nasa_retrieved_at": provenance.retrieved_at.isoformat(),
        "location": {
            "latitude": pilot.latitude,
            "longitude": pilot.longitude,
            "coordinate_meaning": pilot.coordinate_meaning,
        },
        "reference_period": {
            "start_year": pilot.reference_start_year,
            "end_year": pilot.reference_end_year,
        },
        "recent_period": {
            "start_year": pilot.recent_start_year,
            "end_year": pilot.recent_end_year,
        },
        "onset_definition": {
            "window_days": definition.window_days,
            "threshold_mm": definition.threshold_mm,
            "dry_spell_max_days": definition.dry_spell_max_days,
        },
        "yearly_onset": yearly_onset,
        "reference_onset_days": comparison.reference_onset_days,
        "recent_onset_days": comparison.recent_onset_days,
        "reference_median_onset_doy": comparison.reference_median_onset_doy,
        "recent_median_onset_doy": comparison.recent_median_onset_doy,
        "shift_days": comparison.shift_days,
        "data_status": comparison.data_status,
        "mann_whitney": {
            "u_statistic": mann_whitney.u_statistic,
            "p_value": mann_whitney.p_value,
            "data_status": mann_whitney.data_status,
        },
        "sensitivity": [
            {
                "threshold_mm": point.threshold_mm,
                "shift_days": point.comparison.shift_days,
                "reference_median_onset_doy": point.comparison.reference_median_onset_doy,
                "recent_median_onset_doy": point.comparison.recent_median_onset_doy,
                "data_status": point.comparison.data_status,
            }
            for point in sensitivity.points
        ],
        "missing_data": {
            "total_days_in_evidence_range": total_days,
            "days_missing_precipitation": missing_days,
        },
        "generated_at": datetime.now(UTC).isoformat(),
    }


def _rajshahi_han_parameters(pilot: RajshahiAmanPilot) -> HanOnsetParameters:
    return HanOnsetParameters(
        station_name="Rajshahi",
        lws_days=pilot.han_lws_days,
        aws_mm=pilot.han_aws_mm,
        lds_days=pilot.han_lds_days,
        ads_mm=pilot.han_ads_mm,
        search_start_month_day=pilot.han_search_start_month_day,
        search_end_month_day=pilot.han_search_end_month_day,
        wet_day_threshold_mm=pilot.han_wet_day_threshold_mm,
        dry_day_threshold_mm=pilot.han_dry_day_threshold_mm,
        post_onset_lookahead_days=pilot.han_post_onset_lookahead_days,
    )


async def build_han_analysis(
    pilot: RajshahiAmanPilot, *, fixture_dir: Path
) -> dict[str, Any]:
    """Generates the Han et al. (2024) `han_agronomic_onset_v1` analysis
    artifact from the same real, manifest-verified NASA POWER fixture
    `build_analysis` uses - never a new fetch, never synthetic data. See
    docs/references/han_2024_agronomic_onset.md for the algorithm's
    source and docs/references/han_2024_nasa_power_transfer_review.md
    for the BMD-vs-NASA-POWER transfer assessment this artifact feeds.
    """
    response = await _load_real_fixture_response(pilot, fixture_dir=fixture_dir)
    provenance = response.provenance

    precip_by_year = _group_by_year(
        response.records,
        field="precipitation_mm",
        start_year=pilot.reference_start_year,
        end_year=pilot.recent_end_year,
    )

    parameters = _rajshahi_han_parameters(pilot)
    onset_by_year = han_onset_by_year(precip_by_year, parameters=parameters)

    def _found_onset_date(year: int) -> date | None:
        result = onset_by_year.get(year)
        if result is not None and result.found and result.onset_date is not None:
            return result.onset_date
        return None

    reference_years = range(pilot.reference_start_year, pilot.reference_end_year + 1)
    recent_years = range(pilot.recent_start_year, pilot.recent_end_year + 1)

    comparison = compare_han_periods(
        onset_by_year, reference_years=reference_years, recent_years=recent_years
    )
    reference_days = comparison.reference_onset_days
    recent_days = comparison.recent_onset_days
    reference_median = comparison.reference_median_onset_doy
    recent_median = comparison.recent_median_onset_doy
    shift_days = comparison.shift_days
    data_status = comparison.data_status

    mann_whitney = mann_whitney_shift_test(reference_days, recent_days)

    total_years = len(onset_by_year)
    no_onset_years = [y for y, r in onset_by_year.items() if not r.found]
    false_onset_rejections = sum(r.false_onset_candidates_rejected for r in onset_by_year.values())
    missing_data_years = [
        y for y, r in onset_by_year.items() if r.missing_data_status != "ok"
    ]

    found_onset_dates: list[date] = [
        d for y in sorted(onset_by_year) if (d := _found_onset_date(y)) is not None
    ]
    month_counts: dict[str, int] = {}
    for d in found_onset_dates:
        month_counts[str(d.month)] = month_counts.get(str(d.month), 0) + 1

    boundary_days = 3
    near_start_boundary = sum(
        1
        for y in sorted(onset_by_year)
        if (d := _found_onset_date(y)) is not None
        and (d - date(y, *parameters.search_start_month_day)).days <= boundary_days
    )

    yearly_onset: dict[str, dict[str, Any]] = {}
    for year in sorted(onset_by_year):
        result = onset_by_year[year]
        yearly_onset[str(year)] = {
            "found": result.found,
            "onset_date": result.onset_date.isoformat() if result.onset_date else None,
            "onset_day_of_year": result.onset_day_of_year,
            "initial_wet_spell_rainfall_mm": result.initial_wet_spell_rainfall_mm,
            "false_onset_candidates_rejected": result.false_onset_candidates_rejected,
            "missing_data_status": result.missing_data_status,
            "reason": result.reason,
        }

    return {
        "pilot_id": pilot.pilot_id,
        "analysis_version": HAN_ANALYSIS_VERSION,
        "method_id": METHOD_ID,
        "method_version": "1",
        "method_source_doi": METHOD_SOURCE_DOI,
        "source_fixture_sha256": provenance.fixture_sha256,
        "source_fixture_path": provenance.local_evidence_path,
        "nasa_source_url": provenance.source_url,
        "nasa_retrieved_at": provenance.retrieved_at.isoformat(),
        "parameters": {
            "station_name": parameters.station_name,
            "lws_days": parameters.lws_days,
            "aws_mm": parameters.aws_mm,
            "lds_days": parameters.lds_days,
            "ads_mm": parameters.ads_mm,
            "search_start_month_day": list(parameters.search_start_month_day),
            "search_end_month_day": list(parameters.search_end_month_day),
            "wet_day_threshold_mm": parameters.wet_day_threshold_mm,
            "dry_day_threshold_mm": parameters.dry_day_threshold_mm,
            "post_onset_lookahead_days": parameters.post_onset_lookahead_days,
        },
        "reference_period": {
            "start_year": pilot.reference_start_year,
            "end_year": pilot.reference_end_year,
        },
        "recent_period": {
            "start_year": pilot.recent_start_year,
            "end_year": pilot.recent_end_year,
        },
        "yearly_onset": yearly_onset,
        "reference_onset_days": reference_days,
        "recent_onset_days": recent_days,
        "reference_median_onset_doy": reference_median,
        "recent_median_onset_doy": recent_median,
        "shift_days": shift_days,
        "data_status": data_status,
        "mann_whitney": {
            "u_statistic": mann_whitney.u_statistic,
            "p_value": mann_whitney.p_value,
            "data_status": mann_whitney.data_status,
        },
        "diagnostics": {
            "total_years": total_years,
            "no_onset_years": sorted(no_onset_years),
            "no_onset_year_count": len(no_onset_years),
            "false_onset_candidates_rejected_total": false_onset_rejections,
            "years_with_missing_data": sorted(missing_data_years),
            "onset_month_distribution": month_counts,
            "earliest_onset": min(found_onset_dates, default=None),
            "latest_onset": max(found_onset_dates, default=None),
            f"onsets_within_{boundary_days}_days_of_search_start": near_start_boundary,
        },
        "generated_at": datetime.now(UTC).isoformat(),
    }


async def _main(fixture_dir: Path, output_path: Path, *, method: str) -> int:
    try:
        if method == "han":
            analysis = await build_han_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=fixture_dir)
        else:
            analysis = await build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=fixture_dir)
    except (NasaEvidenceIntegrityError, NasaPowerUnavailableOfflineError) as exc:
        print(f"Analysis artifact NOT generated: {exc}", file=sys.stderr)
        return 1

    def _json_default(value: Any) -> Any:
        if isinstance(value, date):
            return value.isoformat()
        raise TypeError(f"Not JSON serializable: {value!r}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(analysis, sort_keys=True, indent=2, default=_json_default), encoding="utf-8"
    )

    print(f"Analysis artifact written: {output_path}")
    print(f"Source fixture SHA-256: {analysis['source_fixture_sha256']}")
    print(f"Reference median onset (DOY): {analysis['reference_median_onset_doy']}")
    print(f"Recent median onset (DOY): {analysis['recent_median_onset_doy']}")
    print(f"Shift days: {analysis['shift_days']}")
    print(f"Data status: {analysis['data_status']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    method = "usable_rain"
    positional = []
    for arg in args:
        if arg in ("--han", "--method=han"):
            method = "han"
        else:
            positional.append(arg)

    default_output = DEFAULT_HAN_OUTPUT_PATH if method == "han" else DEFAULT_OUTPUT_PATH
    fixture_dir = Path(positional[0]) if len(positional) > 0 else DEFAULT_FIXTURE_DIR
    output_path = Path(positional[1]) if len(positional) > 1 else default_output
    return asyncio.run(_main(fixture_dir, output_path, method=method))


if __name__ == "__main__":
    raise SystemExit(main())
