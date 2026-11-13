"""Generate a conservative dataset evidence report from the saved live run."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.integrations.datasets import DATASETS  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "docs/evidence/live_acquisition.json"
OUTPUT = ROOT / "docs/evidence/dataset_matrix.md"


def main() -> None:
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    rows = evidence.get("results", {})
    lines = [
        "# Dataset acquisition evidence matrix",
        "",
        f"Recorded run: {evidence.get('generated_at', 'unknown')}. This is historical evidence, not a live health check.",
        "",
        "ACQUIRED is a recorded sample, not proof of a complete production pipeline. "
        "DISCOVERED is metadata only. Validation, feature integration, and individual "
        "test coverage have not yet been verified by this report.",
        "",
        "| # | Dataset | Access | Acquisition evidence | Blocker / next verification |",
        "|---|---|---|---|---|",
    ]
    for dataset in DATASETS:
        entry = rows.get(f"{dataset.number:02d}", {})
        state = entry.get("status", "NOT_CHECKED") if entry.get("key") == dataset.key else "NOT_CHECKED"
        note = {
            "ACQUIRED": "Sample recorded; validate and verify feature integration.",
            "DISCOVERED": "Metadata only; obtain actual data and verify processing and authentication.",
            "NO_DATA": "No usable values in recorded request; investigate coverage and parameters.",
            "NOT_CHECKED": "No acquisition evidence in this run.",
            "BLOCKED": "Provider access blocked; verify credentials and permissions.",
            "FAILED": "Request failed; inspect the saved acquisition evidence.",
        }.get(state, "Unrecognised status; investigate.")
        name = dataset.name.replace("|", "\\|")
        lines.append(f"| {dataset.number:02d} | {name} | {dataset.access.value} | {state} | {note} |")
    lines.extend([
        "",
        "NASA POWER CMIP6: PRECTOTCORR is a supported parameter, daily coverage is "
        "2015–2100, and missing values may occur within the coverage area. "
        "[NASA POWER Projection API](https://power.larc.nasa.gov/docs/services/api/projection/).",
        "",
    ])
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
