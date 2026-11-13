"""Rebuild `app/integrations/reference/data/bamis_crop_calendars.csv` from
the official BAMIS "Crop Weather Calendar" PDFs.

Usage (pypdf is only needed for this offline build step):
    uv run --with pypdf python scripts/build_bamis_calendar.py <pdf_dir>

Each PDF in <pdf_dir> must be named <id>.pdf, matching `SOURCES` below.
Every output row records the exact BAMIS URL it came from. Rows whose
title disagrees with the stated duration (BAMIS publishing errors) are
written with verified=false and a `qa_note`, never silently corrected.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

BASE = "https://www.bamis.gov.bd/res/public/calendars"
_RANGES = (
    ("2019/08/23", range(5061, 5131)),  # Aus, Aman, Boro, wheat, maize
    ("2019/12/30", range(10970, 11012)),  # jute, mustard
    ("2019/11/14", range(8722, 8735)),  # lentil
)
SOURCES = {n: f"{BASE}/{d}/{n}.pdf" for d, r in _RANGES for n in r}

_CROPS = {
    "aus rice": "aus_rice", "aman rice": "aman_rice", "boro rice": "boro_rice",
    "wheat": "wheat", "maize": "maize", "mazie": "maize", "mustard": "mustard",
    "lentil": "lentil", "jute": "jute",
}  # fmt: skip
# Durations BAMIS states per crop; a mismatch flags a mislabelled sheet.
_EXPECTED_DURATION = {
    "aus_rice": "126", "aman_rice": "133", "boro_rice": "150-155", "wheat": "119",
    "maize": "112", "mustard": "80-100", "lentil": "119", "jute": "110-120",
}  # fmt: skip

# BAMIS title typos -> canonical district names used in bd_districts.json.
_DISTRICT_FIXES = {"Manikgon": "Manikgonj", "Panchaghar": "Panchagarh", "Coxsbazar": "Coxsbazar"}

FIELDS = (
    "crop",
    "region",
    "districts",
    "std_week_start",
    "std_week_end",
    "duration_days",
    "stage",
    "normal_rainfall_mm",
    "water_requirement_mm",
    "water_requirement_lower_bound",
    "source",
    "source_url",
    "verified",
    "qa_note",
)


def _rainfall_total(text: str, n_weeks: int) -> str:
    """Sum of the sheet's weekly normal rainfall row (mm), '' if unparseable."""
    m = re.search(r"Rainfall \(mm\)\s+([0-9. ]+)", text)
    if not m:
        return ""
    vals = [float(v) for v in m.group(1).split()]
    return f"{sum(vals):.1f}" if len(vals) == n_weeks else ""


def _water_requirement(flat: str) -> tuple[str, str]:
    """Sum of 'Normal phase wise water requirement (mm)' cells.

    'At least N' cells count as N and mark the total as a lower bound."""
    m = re.search(r"water requirement \(mm\)\s*((?:(?:At least\s*)?[0-9]+\s*)+)", flat, re.I)
    if not m:
        return "", ""
    cells = re.findall(r"(At least\s*)?([0-9]+)", m.group(1), re.I)
    total = sum(int(v) for _, v in cells)
    return str(total), "true" if any(a for a, _ in cells) else "false"


# fmt: skip


def parse(pdf: Path, url: str) -> dict[str, str] | None:
    import pypdf  # noqa: PLC0415 - build-time only

    text = pypdf.PdfReader(pdf).pages[0].extract_text()
    flat = " ".join(text.split())
    m = re.search(
        r"Calendar of ([A-Za-z ]+?)\s*:\s*([A-Za-z]+?)\s*Region\s*\(Districts?\s*:\s*([^)]+)\)",
        flat,
    )  # noqa: E501
    weeks = re.search(r"Std\.? ?Week/Normal ([0-9 ]+)", text)
    dur = re.search(r"[Dd]uration ?:? ?([0-9]+(?:-[0-9]+)?)", flat)
    if not (m and weeks and dur):
        return None
    crop = _CROPS.get(m.group(1).strip().lower())
    if crop is None:
        return None
    week_list = weeks.group(1).split()
    districts = re.sub(r"\s+and\s+", ", ", m.group(3)).replace(" ,", ",")
    duration = dur.group(1)
    notes = []
    if _EXPECTED_DURATION[crop] != duration:
        notes.append(f"title says {crop} but duration {duration} days does not match")
    if crop == "maize" and week_list[0] == "36":
        notes.append("window weeks 36-51 inconsistent with other maize calendars")
    rain = _rainfall_total(text, len(week_list))
    req, lower = _water_requirement(flat)
    if crop not in ("aus_rice", "aman_rice", "boro_rice") and req == "631":
        # Byte-identical to the rice sheets' 76+120+190+145+100 row: a template
        # copy, not a crop-specific requirement. Withheld, not "corrected".
        notes.append("water requirement equals the rice template (631 mm); withheld")
        req, lower = "", ""
    return {
        "normal_rainfall_mm": rain,
        "water_requirement_mm": req,
        "water_requirement_lower_bound": lower,
        "crop": crop,
        "region": m.group(2).replace("Dinjpur", "Dinajpur"),
        "districts": "; ".join(
            _DISTRICT_FIXES.get(d.strip(), d.strip()) for d in districts.split(",") if d.strip()
        ),
        "std_week_start": week_list[0],
        "std_week_end": week_list[-1],
        "duration_days": duration,
        "stage": "calendar_window",
        "source": "BAMIS Crop Weather Calendar (DAE / BMD / BWDB, 2019)",
        "source_url": url,
        "verified": "false"
        if any("does not match" in n or "inconsistent" in n for n in notes)
        else "true",
        "qa_note": "; ".join(notes),
    }


def main(pdf_dir: Path, out: Path) -> None:
    rows, seen = [], set()
    for n, url in sorted(SOURCES.items()):
        pdf = pdf_dir / f"{n}.pdf"
        if not pdf.exists() or pdf.read_bytes()[:4] != b"%PDF":
            continue
        row = parse(pdf, url)
        if row is None:
            continue
        key = (row["crop"], row["region"], row["std_week_start"], row["std_week_end"])
        if key in seen:  # BAMIS republished some sheets under a second id
            continue
        seen.add(key)
        rows.append(row)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    main(Path(sys.argv[1]), root / "app/integrations/reference/data/bamis_crop_calendars.csv")
