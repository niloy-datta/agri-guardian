"""Deterministic crop-rotation scenario engine.

Pure function of the evidence it is handed - no I/O, no randomness, no
invented thresholds, and no yield / income / confidence numbers.

How a scenario is built and judged (every rule is traceable to evidence):

* Candidates are 2- or 3-crop sets drawn from the BAMIS regional calendar
  for the field's district (dataset #7). A crop appears at most once.
* Calendar fit = total pairwise overlap (days) of the BAMIS calendar
  windows. BAMIS windows can include the nursery/seedbed period, so a small
  overlap is reported as a "transition to check", never hidden; overlap of
  more than `max_overlap_days` (caller-chosen, default 0 = strict) excludes
  the set.
* Water need comes from the SAME BAMIS sheet: its "normal phase wise water
  requirement (mm)" minus its weekly normal rainfall summed over the window.
  A positive deficit means "irrigation-dependent" - conservative, because
  total rainfall overstates effective rainfall. A non-positive deficit only
  says normal total rainfall reaches the stated requirement. Without
  irrigation access an irrigation-dependent crop is excluded. Sheets with
  no (or withheld) requirement give `water_need="unknown"`.
* GAEZ v5 (dataset #6) is season-agnostic (it models each crop's own best
  cycle, not the BAMIS season), so it is NOT used for water need. It is
  reported as suitability context; a crop whose rain-fed AND irrigated
  indices are both 0 at the pixel is excluded as not suitable.
* Ranking uses only the farmer's chosen priorities that the evidence can
  speak to:
    water_saving  -> fewer crops NOT shown to be rainfall-sufficient
                     (irrigation-dependent + unknown), then fewer deficits
    food_security -> more rice seasons
    soil_health   -> contains a pulse (lentil); stated as a fact about the
                     rotation, not as a quantified soil benefit
  `income` and `low_risk` have no price/yield/risk evidence and are
  returned as INSUFFICIENT_EVIDENCE.
  Ties: less calendar overlap, then higher weakest GAEZ index.
* Fewer than 2 feasible scenarios -> status INSUFFICIENT_EVIDENCE.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from itertools import combinations

from app.integrations.reference.crop_calendars import CropWindow, _overlap

RICE = frozenset({"aus_rice", "aman_rice", "boro_rice"})
PULSES = frozenset({"lentil"})
SUPPORTED_PRIORITIES = ("water_saving", "food_security", "soil_health")
UNSUPPORTED_PRIORITIES = ("income", "low_risk")


class Status(StrEnum):
    OK = "OK"
    INSUFFICIENT_EVIDENCE = "INSUFFICIENT_EVIDENCE"


class WaterNeed(StrEnum):
    RAINFED_POSSIBLE = "rainfed_possible"
    IRRIGATION_DEPENDENT = "irrigation_dependent"
    NOT_SUITABLE = "not_suitable"
    UNKNOWN = "unknown"


@dataclass(frozen=True, slots=True)
class CropEvidence:
    crop: str
    window: CropWindow
    gaez_rainfed: int | None = None
    gaez_irrigated: int | None = None
    gaez_source: str | None = None

    @property
    def gaez_not_suitable(self) -> bool:
        return self.gaez_rainfed == 0 and self.gaez_irrigated == 0

    @property
    def water_deficit_mm(self) -> float | None:
        req, rain = self.window.water_requirement_mm, self.window.normal_rainfall_mm
        return None if req is None or rain is None else req - rain

    @property
    def water_need(self) -> WaterNeed:
        deficit = self.water_deficit_mm
        if deficit is None:
            return WaterNeed.UNKNOWN
        if deficit > 0:
            return WaterNeed.IRRIGATION_DEPENDENT
        # A lower-bound requirement met by rainfall proves nothing.
        if self.window.water_requirement_lower_bound:
            return WaterNeed.UNKNOWN
        return WaterNeed.RAINFED_POSSIBLE


@dataclass(frozen=True, slots=True)
class Claim:
    text: str
    source: str
    uncertainty: str


@dataclass(frozen=True, slots=True)
class Scenario:
    crops: tuple[str, ...]
    overlap_days: int
    irrigation_dependent: tuple[str, ...]
    unknown_water_need: tuple[str, ...]
    rice_seasons: int
    has_pulse: bool
    weakest_gaez_index: int | None
    claims: tuple[Claim, ...]


@dataclass(frozen=True, slots=True)
class RotationResult:
    status: Status
    scenarios: tuple[Scenario, ...]
    excluded: tuple[tuple[str, str], ...]
    """(crop, reason) for crops removed before combination."""
    unsupported_priorities: tuple[str, ...]
    reasons: tuple[str, ...] = field(default=())


def _agri_year_key(ev: CropEvidence) -> tuple[int, int]:
    m, d = ev.window.start
    return ((m - 4) % 12, d)  # Bangladesh agricultural year starts with Aus (April)


def _scenario(evs: tuple[CropEvidence, ...]) -> Scenario:
    evs = tuple(sorted(evs, key=_agri_year_key))
    overlap = sum(_overlap(a.window, b.window) for a, b in combinations(evs, 2))
    irr = tuple(e.crop for e in evs if e.water_need is WaterNeed.IRRIGATION_DEPENDENT)
    unk = tuple(e.crop for e in evs if e.water_need is WaterNeed.UNKNOWN)
    idx = [
        max(e.gaez_rainfed or 0, e.gaez_irrigated or 0) for e in evs if e.gaez_rainfed is not None
    ]
    claims = [
        Claim(
            f"{e.crop}: BAMIS {e.window.region} calendar window "
            f"{e.window.start[1]:02d}/{e.window.start[0]:02d}-{e.window.end[1]:02d}/{e.window.end[0]:02d}"
            f" ({e.window.duration_days} days)",
            e.window.source_url,
            "Regional calendar for a multi-district BAMIS region; not field-specific. "
            "Window may include the nursery period.",
        )
        for e in evs
    ]
    for e in evs:
        w = e.window
        if e.water_deficit_mm is not None:
            bound = "at least " if w.water_requirement_lower_bound else ""
            claims.append(Claim(
                f"{e.crop}: BAMIS water requirement {bound}{w.water_requirement_mm:.0f} mm vs normal "
                f"rainfall {w.normal_rainfall_mm:.0f} mm in the window -> {e.water_need.value}",
                w.source_url,
                "Total (not effective) normal rainfall; regional normals, not this season's weather.",
            ))  # fmt: skip
        else:
            claims.append(Claim(f"{e.crop}: BAMIS sheet gives no usable water requirement; "
                                "water need unknown", w.source_url, "No evidence."))  # fmt: skip
        if e.gaez_rainfed is not None:
            claims.append(Claim(
                f"{e.crop}: GAEZ v5 suitability index rain-fed {e.gaez_rainfed}, "
                f"irrigated {e.gaez_irrigated}",
                e.gaez_source or "",
                "Modelled 5 arc-min (~9 km) index for the crop's own optimal cycle (not this "
                "season), 2001-2020 climate, high input; not an observed yield.",
            ))  # fmt: skip
    if overlap:
        claims.append(Claim(
            f"Calendar windows overlap by {overlap} day(s); check whether the earlier crop is "
            "harvested before the next is transplanted.", "BAMIS calendars", "Calendar-level only.",
        ))  # fmt: skip
    return Scenario(
        crops=tuple(e.crop for e in evs),
        overlap_days=overlap,
        irrigation_dependent=irr,
        unknown_water_need=unk,
        rice_seasons=sum(e.crop in RICE for e in evs),
        has_pulse=any(e.crop in PULSES for e in evs),
        weakest_gaez_index=min(idx) if idx else None,
        claims=tuple(claims),
    )


def _rank_key(s: Scenario, priorities: tuple[str, ...]) -> tuple[int, ...]:
    key: list[int] = []
    for p in priorities:
        if p == "water_saving":
            # Unknown water need is not evidence of saving water: count every
            # crop not shown to be rainfall-sufficient, then the known deficits.
            key += [
                len(s.irrigation_dependent) + len(s.unknown_water_need),
                len(s.irrigation_dependent),
            ]
        elif p == "food_security":
            key.append(-s.rice_seasons)
        elif p == "soil_health":
            key.append(0 if s.has_pulse else 1)
    key += [s.overlap_days, -(s.weakest_gaez_index or 0), len(s.unknown_water_need)]
    return tuple(key)


def generate_rotations(
    evidence: list[CropEvidence],
    *,
    has_irrigation: bool,
    priorities: tuple[str, ...] = (),
    max_overlap_days: int = 0,
    max_scenarios: int = 3,
) -> RotationResult:
    excluded: list[tuple[str, str]] = []
    usable: list[CropEvidence] = []
    for e in evidence:
        if e.gaez_not_suitable:
            excluded.append((e.crop, "GAEZ v5 index is 0 under both rain-fed and irrigated supply"))
        elif e.water_need is WaterNeed.IRRIGATION_DEPENDENT and not has_irrigation:
            excluded.append((e.crop, f"BAMIS water requirement exceeds normal rainfall by "
                                     f"{e.water_deficit_mm:.0f} mm and the farmer has no irrigation"))  # fmt: skip
        else:
            usable.append(e)
    supported = tuple(p for p in priorities if p in SUPPORTED_PRIORITIES)
    unsupported = tuple(p for p in priorities if p in UNSUPPORTED_PRIORITIES)

    candidates = [_scenario(combo) for size in (3, 2) for combo in combinations(usable, size)]
    feasible = [s for s in candidates if s.overlap_days <= max_overlap_days]
    feasible.sort(key=lambda s: (_rank_key(s, supported), s.crops))
    # Prefer 3-crop sets but never drop a better-ranked 2-crop set for one.
    chosen: list[Scenario] = []
    for s in feasible:
        if not any(set(s.crops) <= set(c.crops) for c in chosen):
            chosen.append(s)
        if len(chosen) == max_scenarios:
            break
    reasons: list[str] = []
    if not evidence:
        reasons.append("No BAMIS calendar is available for this location.")
    if len(chosen) < 2:
        reasons.append(
            f"Only {len(chosen)} scenario(s) satisfy the calendar (overlap <= {max_overlap_days} days) "
            "and water-supply constraints; at least 2 are needed for a comparison."
        )
    status = Status.OK if len(chosen) >= 2 else Status.INSUFFICIENT_EVIDENCE
    return RotationResult(status, tuple(chosen), tuple(excluded), unsupported, tuple(reasons))
