#!/usr/bin/env python
"""Phase 4A.2c — Han/NASA POWER transfer validation gate.

Independently re-derives every number this script reports directly from
the real, manifest-verified NASA POWER fixture and the pure functions in
`app/compute/monsoon_onset.py` / `app/compute/han_validation.py` - it
never copies a figure out of `docs/references/han_2024_nasa_power_transfer_review.md`
or any other prose document. If this script's recomputed numbers ever
disagree with that document, that document is wrong and must be corrected
to match this script's output, not the other way around.

This script also looks for an independent evidence source (something
genuinely separate from NASA POWER, e.g. a committed BMD station series
or an MCD12Q2 phenology cross-check) at `demo_fixtures/independent_evidence/`.
As of Phase 4A.2c, no such source has been acquired - this is disclosed,
not hidden, and the resulting validation status honestly reflects it
(`insufficient_evidence`), per this phase's own explicit acceptance that
this is a legitimate, successful outcome.

Usage (from `backend/api`):

    python scripts/validate_han_transfer.py
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

from app.compute.agro import mann_whitney_shift_test  # noqa: E402
from app.compute.han_validation import (  # noqa: E402
    DEFAULT_BOUNDARY_DAYS,
    classify_han_transfer_validation,
    compute_boundary_clustering,
    default_rajshahi_sensitivity_perturbations,
    run_han_sensitivity_perturbations,
)
from app.compute.monsoon_onset import compare_han_periods, han_onset_by_year  # noqa: E402
from app.integrations.nasa.power_cache import (  # noqa: E402
    NasaEvidenceIntegrityError,
    NasaPowerUnavailableOfflineError,
)
from app.modules.advisory.pilots.rajshahi_aman import RAJSHAHI_AMAN_PILOT  # noqa: E402
from scripts.build_pilot_analysis import (  # noqa: E402
    DEFAULT_FIXTURE_DIR,
    _group_by_year,
    _load_real_fixture_response,
    _rajshahi_han_parameters,
)

VALIDATION_VERSION = "1"
DEFAULT_OUTPUT_PATH = (
    REPO_ROOT / "demo_fixtures" / "analysis" / "rajshahi_aman_han_2024_validation.json"
)
INDEPENDENT_EVIDENCE_DIR = REPO_ROOT / "demo_fixtures" / "independent_evidence"


def _discover_independent_evidence() -> tuple[bool, str, list[str]]:
    """Never fabricates or extrapolates independent evidence. A source
    only counts if it is a real, committed file under
    `demo_fixtures/independent_evidence/` - nothing in this phase writes
    to that directory, so its absence here is expected and honest."""
    if not INDEPENDENT_EVIDENCE_DIR.is_dir():
        return False, "no_independent_evidence_directory_present", []
    files = sorted(p.name for p in INDEPENDENT_EVIDENCE_DIR.glob("*") if p.is_file())
    if not files:
        return False, "independent_evidence_directory_empty", []
    return True, "independent_evidence_files_present", files


async def build_validation(*, fixture_dir: Path) -> dict[str, Any]:
    pilot = RAJSHAHI_AMAN_PILOT
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

    reference_years = range(pilot.reference_start_year, pilot.reference_end_year + 1)
    recent_years = range(pilot.recent_start_year, pilot.recent_end_year + 1)

    # ---- Independently re-derived (not copied from any doc) period
    # comparison + significance test, from the raw per-year onset dates.
    comparison = compare_han_periods(
        onset_by_year, reference_years=reference_years, recent_years=recent_years
    )
    mann_whitney = mann_whitney_shift_test(
        comparison.reference_onset_days, comparison.recent_onset_days
    )

    no_onset_years = sorted(y for y, r in onset_by_year.items() if not r.found)
    false_onset_rejections_total = sum(r.false_onset_candidates_rejected for r in onset_by_year.values())
    missing_data_years = sorted(y for y, r in onset_by_year.items() if r.missing_data_status != "ok")

    # ---- Boundary clustering at 1/2/3/5/7 days (Task 15).
    boundary_clustering = compute_boundary_clustering(
        onset_by_year,
        search_start_month_day=parameters.search_start_month_day,
        boundary_days_list=DEFAULT_BOUNDARY_DAYS,
    )

    # ---- Predefined, transparent sensitivity perturbations (Task 16/17).
    perturbations = default_rajshahi_sensitivity_perturbations(parameters)
    sensitivity_results = run_han_sensitivity_perturbations(
        precip_by_year,
        base_parameters=parameters,
        perturbations=perturbations,
        reference_years=reference_years,
        recent_years=recent_years,
    )

    # ---- Independent validation evidence (Task 18/19/28).
    independent_evidence_available, independent_evidence_status, independent_evidence_files = (
        _discover_independent_evidence()
    )

    validation = classify_han_transfer_validation(
        boundary_clustering=boundary_clustering,
        sensitivity_results=sensitivity_results,
        independent_evidence_available=independent_evidence_available,
    )

    yearly_onset: dict[str, dict[str, Any]] = {}
    for year in sorted(onset_by_year):
        result = onset_by_year[year]
        yearly_onset[str(year)] = {
            "found": result.found,
            "onset_date": result.onset_date.isoformat() if result.onset_date else None,
            "onset_day_of_year": result.onset_day_of_year,
            "false_onset_candidates_rejected": result.false_onset_candidates_rejected,
            "missing_data_status": result.missing_data_status,
        }

    return {
        "pilot_id": pilot.pilot_id,
        "validation_version": VALIDATION_VERSION,
        "method_id": parameters.station_name,
        "source_fixture_sha256": provenance.fixture_sha256,
        "reproduced_from": (
            "Independently recomputed in this phase from the raw committed NASA "
            "POWER fixture and the published Rajshahi Table 1 parameters - not "
            "copied from docs/references/han_2024_nasa_power_transfer_review.md."
        ),
        "published_parameters": {
            "station_name": parameters.station_name,
            "lws_days": parameters.lws_days,
            "aws_mm": parameters.aws_mm,
            "lds_days": parameters.lds_days,
            "ads_mm": parameters.ads_mm,
            "search_start_month_day": list(parameters.search_start_month_day),
            "search_end_month_day": list(parameters.search_end_month_day),
        },
        "yearly_onset": yearly_onset,
        "reproduced_metrics": {
            "reference_onset_days": comparison.reference_onset_days,
            "recent_onset_days": comparison.recent_onset_days,
            "reference_median_onset_doy": comparison.reference_median_onset_doy,
            "recent_median_onset_doy": comparison.recent_median_onset_doy,
            "shift_days": comparison.shift_days,
            "data_status": comparison.data_status,
            "mann_whitney_u": mann_whitney.u_statistic,
            "p_value": mann_whitney.p_value,
            "mann_whitney_data_status": mann_whitney.data_status,
            "no_onset_years": no_onset_years,
            "false_onset_candidates_rejected_total": false_onset_rejections_total,
            "years_with_missing_data": missing_data_years,
        },
        "boundary_clustering": [
            {
                "boundary_days": point.boundary_days,
                "years_within_boundary": point.years_within_boundary,
                "found_year_count": point.found_year_count,
                "percentage": point.percentage,
            }
            for point in boundary_clustering
        ],
        "sensitivity": [
            {
                "parameter_name": run.perturbation.parameter_name,
                "original_value": run.perturbation.original_value,
                "changed_value": run.perturbation.changed_value,
                "reason": run.perturbation.reason,
                "resulting_shift_days": run.comparison.shift_days,
                "resulting_data_status": run.comparison.data_status,
                "resulting_mann_whitney_p_value": run.mann_whitney.p_value,
                "no_onset_year_count": run.no_onset_year_count,
                "false_onset_candidates_rejected_total": run.false_onset_candidates_rejected_total,
                "label": "SENSITIVITY_EXPERIMENT_NOT_PUBLISHED_HAN_CONFIGURATION",
            }
            for run in sensitivity_results
        ],
        "independent_evidence_status": independent_evidence_status,
        "independent_evidence_available": independent_evidence_available,
        "independent_evidence_files": independent_evidence_files,
        "validation_status": validation.status,
        "validation_reason_codes": validation.reason_codes,
        "decision_enabled_before_this_phase": False,
        "decision_enabled_after_this_phase": pilot.decision_enabled,
        "generated_at": datetime.now(UTC).isoformat(),
    }


async def _main(fixture_dir: Path, output_path: Path) -> int:
    try:
        validation = await build_validation(fixture_dir=fixture_dir)
    except (NasaEvidenceIntegrityError, NasaPowerUnavailableOfflineError) as exc:
        print(f"Validation artifact NOT generated: {exc}", file=sys.stderr)
        return 1

    def _json_default(value: Any) -> Any:
        if isinstance(value, date):
            return value.isoformat()
        raise TypeError(f"Not JSON serializable: {value!r}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(validation, sort_keys=True, indent=2, default=_json_default), encoding="utf-8"
    )

    print(f"Validation artifact written: {output_path}")
    print(f"Source fixture SHA-256: {validation['source_fixture_sha256']}")
    print(f"Validation status: {validation['validation_status']}")
    print(f"Reason codes: {validation['validation_reason_codes']}")
    print(f"Independent evidence available: {validation['independent_evidence_available']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    fixture_dir = Path(args[0]) if len(args) > 0 else DEFAULT_FIXTURE_DIR
    output_path = Path(args[1]) if len(args) > 1 else DEFAULT_OUTPUT_PATH
    return asyncio.run(_main(fixture_dir, output_path))


if __name__ == "__main__":
    raise SystemExit(main())
