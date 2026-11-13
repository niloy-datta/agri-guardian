"""Crop-calendar windows and rotation-timing checks.

Covers three catalogued datasets: the BRRI/BBS rice calendar (#2), the
BAMIS/DAE crop-weather calendar (#7) and the FAO Global Crop Calendar (#8).

Only the BRRI/BBS Aman HYV transplanting row is held in code, because it is
the one row this project has verified (`docs/references/
rajshahi_aman_pilot.md`). Boro, mustard, lentil and every FAO row must be
loaded from a CSV whose every row carries its source URL - the module
deliberately ships no un-cited dates.

CSV columns: crop, season, stage, start_month, start_day, end_month,
end_day, source, source_url, verified (true/false).
"""

from __future__ import annotations

import csv
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import date
from pathlib import Path

_STAGES = frozenset(
    {"sowing", "transplanting", "growing", "harvest", "field_occupancy", "calendar_window"}
)
_BAMIS_CSV = Path(__file__).parent / "data" / "bamis_crop_calendars.csv"


def std_week_dates(week: int) -> tuple[tuple[int, int], tuple[int, int]]:
    """(month, day) start/end of a standard meteorological week (WMO / BMD
    convention: week 1 = 1-7 January, week 52 = 24-31 December)."""
    if not 1 <= week <= 52:
        raise ValueError(f"standard week {week} out of range 1..52")
    start = date(2001, 1, 1).toordinal() + 7 * (week - 1)
    end = date(2001, 12, 31).toordinal() if week == 52 else start + 6
    s, e = date.fromordinal(start), date.fromordinal(end)
    return (s.month, s.day), (e.month, e.day)


@dataclass(frozen=True, slots=True)
class CropWindow:
    crop: str
    season: str
    stage: str
    start: tuple[int, int]
    """(month, day)."""
    end: tuple[int, int]
    """(month, day); may be earlier than `start` when the window spans the new year."""
    source: str
    source_url: str
    verified: bool
    region: str | None = None
    districts: tuple[str, ...] = ()
    duration_days: str | None = None
    qa_note: str = ""
    normal_rainfall_mm: float | None = None
    """Sum of the sheet's weekly normal rainfall over the window."""
    water_requirement_mm: float | None = None
    """Sum of the sheet's 'normal phase wise water requirement'."""
    water_requirement_lower_bound: bool = False

    def __post_init__(self) -> None:
        if self.stage not in _STAGES:
            raise ValueError(f"unknown stage {self.stage!r}; expected one of {sorted(_STAGES)}")
        for m, d in (self.start, self.end):
            date(2001, m, d)  # raises on an impossible date (2001: non-leap, rejects Feb 29)

    @property
    def wraps_year(self) -> bool:
        return self.end < self.start

    def day_span(self) -> list[tuple[int, int]]:
        """Day-of-year intervals (non-leap) covered by the window."""
        s = date(2001, *self.start).timetuple().tm_yday
        e = date(2001, *self.end).timetuple().tm_yday
        return [(s, e)] if s <= e else [(s, 365), (1, e)]

    def contains(self, day: date) -> bool:
        md = (day.month, day.day)
        if self.wraps_year:
            return md >= self.start or md <= self.end
        return self.start <= md <= self.end


BRRI_AMAN_HYV_TRANSPLANT = CropWindow(
    crop="aman_rice",
    season="aman",
    stage="transplanting",
    start=(6, 25),  # "Late June", approximated - see pilot source document
    end=(8, 15),  # "Mid-August", approximated
    source="BRRI Rice Crop Calendar of Bangladesh (BBS Yearbook of Agricultural Statistics 2023)",
    source_url="docs/references/rajshahi_aman_pilot.md",
    verified=True,
)


def load_calendar_csv(path: Path) -> list[CropWindow]:
    """Load cited calendar rows (BAMIS/DAE, FAO) from a CSV file."""
    rows: list[CropWindow] = []
    with path.open(newline="", encoding="utf-8") as fh:
        for n, r in enumerate(csv.DictReader(fh), start=2):
            if not (r.get("source_url") or "").strip():
                raise ValueError(f"{path.name}:{n}: every calendar row needs a source_url")
            rows.append(
                CropWindow(
                    crop=r["crop"].strip(),
                    season=r["season"].strip(),
                    stage=r["stage"].strip(),
                    start=(int(r["start_month"]), int(r["start_day"])),
                    end=(int(r["end_month"]), int(r["end_day"])),
                    source=r["source"].strip(),
                    source_url=r["source_url"].strip(),
                    verified=r.get("verified", "").strip().lower() == "true",
                )
            )
    return rows


def load_bamis_calendar(path: Path = _BAMIS_CSV) -> list[CropWindow]:
    """BAMIS regional crop-weather calendars (dataset #7), one row per
    crop x region, built from the official PDFs by
    `scripts/build_bamis_calendar.py`."""
    rows: list[CropWindow] = []
    with path.open(newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            start, _ = std_week_dates(int(r["std_week_start"]))
            _, end = std_week_dates(int(r["std_week_end"]))
            rows.append(
                CropWindow(
                    crop=r["crop"],
                    season=r["crop"].split("_")[0],
                    stage=r["stage"],
                    start=start,
                    end=end,
                    source=r["source"],
                    source_url=r["source_url"],
                    verified=r["verified"] == "true",
                    region=r["region"],
                    districts=tuple(d.strip() for d in r["districts"].split(";")),
                    duration_days=r["duration_days"],
                    qa_note=r["qa_note"],
                    normal_rainfall_mm=float(r["normal_rainfall_mm"])
                    if r["normal_rainfall_mm"]
                    else None,
                    water_requirement_mm=(
                        float(r["water_requirement_mm"]) if r["water_requirement_mm"] else None
                    ),
                    water_requirement_lower_bound=r["water_requirement_lower_bound"] == "true",
                )
            )
    return rows


def calendars_for_district(district: str, *, include_unverified: bool = False) -> list[CropWindow]:
    """Calendar windows for the BAMIS region that contains `district`."""
    key = district.strip().lower()
    return [
        w
        for w in load_bamis_calendar()
        if key in (d.lower() for d in w.districts) and (w.verified or include_unverified)
    ]


@dataclass(frozen=True, slots=True)
class RotationConflict:
    first: CropWindow
    second: CropWindow
    overlap_days: int

    def describe(self) -> str:
        return (
            f"{self.first.crop} ({self.first.stage}) overlaps {self.second.crop} "
            f"({self.second.stage}) by {self.overlap_days} day(s)"
        )


def _overlap(a: CropWindow, b: CropWindow) -> int:
    total = 0
    for s1, e1 in a.day_span():
        for s2, e2 in b.day_span():
            total += max(0, min(e1, e2) - max(s1, s2) + 1)
    return total


def rotation_conflicts(
    sequence: Sequence[str], windows: Iterable[CropWindow], *, stage: str = "field_occupancy"
) -> tuple[list[RotationConflict], list[str]]:
    """Check consecutive crops in a rotation for field-occupancy overlap.

    Returns (conflicts, crops_without_data). A crop with no window for
    `stage` is reported as missing - never treated as conflict-free.
    """
    by_crop: dict[str, CropWindow] = {}
    for w in windows:
        if w.stage == stage:
            by_crop.setdefault(w.crop, w)
    missing = [c for c in dict.fromkeys(sequence) if c not in by_crop]
    conflicts: list[RotationConflict] = []
    if len(sequence) < 2:
        return conflicts, missing
    pairs = list(zip(sequence, list(sequence[1:]) + [sequence[0]], strict=True))
    if len(sequence) == 2:
        pairs = pairs[:1]
    for a, b in pairs:
        if a in by_crop and b in by_crop:
            days = _overlap(by_crop[a], by_crop[b])
            if days:
                conflicts.append(RotationConflict(by_crop[a], by_crop[b], days))
    return conflicts, missing
