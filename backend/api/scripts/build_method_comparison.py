#!/usr/bin/env python
"""Generates a side-by-side comparison of the two onset methods.

Compares `usable_rain_v1` (`app/compute/agro.py`, the project's original
ad hoc definition) against `han_agronomic_onset_v1` (`app/compute/
monsoon_onset.py`, Han et al. 2024's Rajshahi-fitted Dynamic-2 method),
both run against the exact same real, manifest-verified NASA POWER
fixture. This script does not judge which method is "better" - it lays
out both methods' yearly onset dates, medians, shifts, and false-start
behavior so the comparison is visible, per Task 12's explicit instruction
not to force either method to look better.

Usage (from `backend/api`):

    python scripts/build_method_comparison.py
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

from app.integrations.nasa.power_cache import (  # noqa: E402
    NasaEvidenceIntegrityError,
    NasaPowerUnavailableOfflineError,
)
from app.modules.advisory.pilots.rajshahi_aman import RAJSHAHI_AMAN_PILOT  # noqa: E402
from scripts.build_pilot_analysis import (  # noqa: E402
    DEFAULT_FIXTURE_DIR,
    build_analysis,
    build_han_analysis,
)

DEFAULT_OUTPUT_PATH = (
    REPO_ROOT / "demo_fixtures" / "analysis" / "rajshahi_aman_method_comparison.json"
)


def _month_of(iso_date: str | None) -> int | None:
    return date.fromisoformat(iso_date).month if iso_date else None


async def build_comparison(*, fixture_dir: Path) -> dict[str, Any]:
    old = await build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=fixture_dir)
    han = await build_han_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=fixture_dir)

    if old["source_fixture_sha256"] != han["source_fixture_sha256"]:
        raise NasaEvidenceIntegrityError(
            "Both methods must run against the exact same fixture SHA-256; "
            f"got {old['source_fixture_sha256']!r} vs {han['source_fixture_sha256']!r}"
        )

    old_month_counts: dict[str, int] = {}
    for entry in old["yearly_onset"].values():
        month = _month_of(entry["onset_date"])
        if month is not None:
            old_month_counts[str(month)] = old_month_counts.get(str(month), 0) + 1

    old_no_onset_years = [
        int(year) for year, entry in old["yearly_onset"].items() if not entry["found"]
    ]

    return {
        "pilot_id": RAJSHAHI_AMAN_PILOT.pilot_id,
        "source_fixture_sha256": old["source_fixture_sha256"],
        "reference_period": old["reference_period"],
        "recent_period": old["recent_period"],
        "usable_rain_v1": {
            "method_id": "usable_rain_v1",
            "onset_definition": old["onset_definition"],
            "yearly_onset": {
                year: entry["onset_date"] for year, entry in old["yearly_onset"].items()
            },
            "onset_month_distribution": old_month_counts,
            "no_onset_years": old_no_onset_years,
            "reference_median_onset_doy": old["reference_median_onset_doy"],
            "recent_median_onset_doy": old["recent_median_onset_doy"],
            "shift_days": old["shift_days"],
            "data_status": old["data_status"],
            "note": (
                "This project's own ad hoc definition, unrestricted by "
                "calendar season. Empirically detects Rajshahi's Feb-Apr "
                "pre-monsoon rainfall in most years, not the June monsoon "
                "transition relevant to Aman transplanting - see "
                "docs/references/nasa_dataset_strategy_audit.md."
            ),
        },
        "han_agronomic_onset_v1": {
            "method_id": han["method_id"],
            "method_source_doi": han["method_source_doi"],
            "parameters": han["parameters"],
            "yearly_onset": {
                year: entry["onset_date"] for year, entry in han["yearly_onset"].items()
            },
            "onset_month_distribution": han["diagnostics"]["onset_month_distribution"],
            "no_onset_years": han["diagnostics"]["no_onset_years"],
            "false_onset_candidates_rejected_total": han["diagnostics"][
                "false_onset_candidates_rejected_total"
            ],
            "reference_median_onset_doy": han["reference_median_onset_doy"],
            "recent_median_onset_doy": han["recent_median_onset_doy"],
            "shift_days": han["shift_days"],
            "data_status": han["data_status"],
            "note": (
                "Han et al. (2024) Rajshahi-fitted Dynamic-2 parameters, "
                "searched only within May 15-Oct 31. See "
                "docs/references/han_2024_nasa_power_transfer_review.md "
                "for the plausibility assessment against the paper's own "
                "reported Rajshahi behavior - not asserted here to be "
                "correct merely because its onset dates fall later in the "
                "year."
            ),
        },
        "generated_at": datetime.now(UTC).isoformat(),
    }


async def _main(fixture_dir: Path, output_path: Path) -> int:
    try:
        comparison = await build_comparison(fixture_dir=fixture_dir)
    except (NasaEvidenceIntegrityError, NasaPowerUnavailableOfflineError) as exc:
        print(f"Comparison artifact NOT generated: {exc}", file=sys.stderr)
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(comparison, sort_keys=True, indent=2), encoding="utf-8")

    print(f"Comparison artifact written: {output_path}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    fixture_dir = Path(args[0]) if len(args) > 0 else DEFAULT_FIXTURE_DIR
    output_path = Path(args[1]) if len(args) > 1 else DEFAULT_OUTPUT_PATH
    return asyncio.run(_main(fixture_dir, output_path))


if __name__ == "__main__":
    raise SystemExit(main())
