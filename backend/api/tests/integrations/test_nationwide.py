"""Nationwide location, BAMIS calendar, GAEZ decoder and rotation-engine tests.

Offline. Location and calendar tests run against the REAL bundled reference
files (GeoNames / geoBoundaries / BAMIS-derived). Engine tests use
CONSTRUCTED CropWindow inputs (labelled synthetic) to pin the rules.
"""

from __future__ import annotations

import json
import struct
from datetime import date
from pathlib import Path

import pytest

from app.compute.rotation_engine import CropEvidence, Status, WaterNeed, generate_rotations
from app.integrations.fao.gaez import CROP_CODES, layer_url, lzw_decode
from app.integrations.reference import bd_locations as loc
from app.integrations.reference.crop_calendars import (
    CropWindow,
    calendars_for_district,
    load_bamis_calendar,
    std_week_dates,
)

# Field-trip reference points (approximate town centres, public map data).
TOWNS = {
    "Rajshahi": (24.374, 88.601), "Sylhet": (24.8949, 91.8687), "Sunamganj": (25.0658, 91.3950),
    "Satkhira": (22.7185, 89.0705), "Khulna": (22.8456, 89.5403), "Rangpur": (25.7439, 89.2752),
    "Barishal": (22.7010, 90.3535),
}  # fmt: skip


def test_eight_divisions_and_sixty_four_districts() -> None:
    assert len(loc.divisions()) == 8
    assert len(loc.districts()) == 64
    assert {d.division for d in loc.districts()} == set(loc.divisions())


@pytest.mark.parametrize("district", [d.name for d in loc.districts()])
def test_every_district_centroid_routes_to_itself_and_has_calendars(district: str) -> None:
    d = loc.get_district(district)
    r = loc.resolve_point(*d.centroid)
    assert r.in_bangladesh and r.district == district and r.division == d.division
    windows = calendars_for_district(district)
    crops = {w.crop for w in windows}
    assert "boro_rice" in crops
    # Known BAMIS gap: the only Mymensingh-region Aman sheet (5084.pdf) is
    # titled "Aus Rice", so it is flagged unverified and not served.
    if windows[0].region != "Mymensingh":
        assert "aman_rice" in crops


@pytest.mark.parametrize(("name", "point"), TOWNS.items())
def test_named_regional_towns(name: str, point: tuple[float, float]) -> None:
    assert loc.resolve_point(*point).district == name


@pytest.mark.parametrize("point", [(22.5726, 88.3639), (20.5, 90.0), (26.2, 91.9), (0.0, 0.0)])
def test_points_outside_bangladesh(point: tuple[float, float]) -> None:
    r = loc.resolve_point(*point)
    assert not r.in_bangladesh and r.district is None


def test_field_polygon_resolution_and_rejection() -> None:
    ring = [
        [88.600, 24.370],
        [88.602, 24.370],
        [88.602, 24.372],
        [88.600, 24.372],
        [88.600, 24.370],
    ]
    assert loc.resolve_field(ring).district == "Rajshahi"
    with pytest.raises(loc.OutsideBangladeshError):
        loc.resolve_field([[88.36, 22.57], [88.37, 22.57], [88.37, 22.58], [88.36, 22.57]])


def test_no_location_defaults_to_rajshahi() -> None:
    assert loc.resolve_point(24.8949, 91.8687).district != "Rajshahi"


def test_std_week_dates() -> None:
    assert std_week_dates(1) == ((1, 1), (1, 7))
    assert std_week_dates(52) == ((12, 24), (12, 31))
    with pytest.raises(ValueError):
        std_week_dates(53)


def test_bamis_calendar_rows_are_all_cited_and_flagged() -> None:
    rows = load_bamis_calendar()
    assert len(rows) == 96
    assert all(r.source_url.startswith("https://www.bamis.gov.bd/") for r in rows)
    assert {r.crop for r in rows} >= {
        "aman_rice",
        "boro_rice",
        "aus_rice",
        "mustard",
        "lentil",
        "wheat",
    }
    flagged = [r for r in rows if not r.verified]
    assert len(flagged) == 3 and all(r.qa_note for r in flagged)
    assert not any(r.crop == "maize" and r.water_requirement_mm == 631 for r in rows)


def test_rajshahi_boro_values_match_primary_pdf() -> None:
    boro = next(w for w in calendars_for_district("Rajshahi") if w.crop == "boro_rice")
    # BAMIS 5105.pdf: weeks 49..19, requirement 76+120+190+145+100, weekly rainfall row sum.
    assert boro.start == (12, 3) and boro.end == (5, 13)
    assert boro.water_requirement_mm == 631 and boro.normal_rainfall_mm == 167.0


FIXTURE = Path(__file__).resolve().parents[1] / "fixtures" / "gaez"


def test_lzw_decoder_matches_libtiff_on_real_gaez_tile() -> None:
    """REAL data: one compressed tile of the GAEZ v5 wetland-rice layer over
    Bangladesh; expected pixels were decoded independently by Pillow/libtiff."""
    meta = json.loads((FIXTURE / "rcw_hilm_tile.json").read_text(encoding="utf-8"))
    raw = lzw_decode((FIXTURE / "rcw_hilm_tile.lzw").read_bytes())
    assert len(raw) == 256 * 256 * 2
    for r, c, expected in meta["expected_by_pillow_libtiff"]:
        assert struct.unpack_from("<h", raw, (r * 256 + c) * 2)[0] == expected


def test_gaez_layer_names_and_crop_gaps() -> None:
    assert layer_url("RCW", "HRLM").endswith("GAEZ-V5.RES05-SXX.HP0120.AGERA5.HIST.RCW.HRLM.tif")
    assert "lentil" not in CROP_CODES and "jute" not in CROP_CODES
    assert "proxy" in CROP_CODES["mustard"][1]


# -- engine (SYNTHETIC inputs) -------------------------------------------------


def _ev(crop: str, start: tuple[int, int], end: tuple[int, int], req: float | None = None,
        rain: float | None = None, gaez: tuple[int, int] | None = (5000, 5000)) -> CropEvidence:  # fmt: skip
    w = CropWindow(crop, crop, "calendar_window", start, end, "synthetic", "https://example",
                   True, water_requirement_mm=req, normal_rainfall_mm=rain)  # fmt: skip
    return CropEvidence(crop, w, *(gaez or (None, None)))


def test_water_need_from_bamis_deficit() -> None:
    assert _ev("boro_rice", (12, 1), (4, 30), 631, 167).water_need is WaterNeed.IRRIGATION_DEPENDENT
    assert _ev("aman_rice", (7, 1), (11, 15), 631, 1118).water_need is WaterNeed.RAINFED_POSSIBLE
    assert _ev("mustard", (11, 15), (2, 25)).water_need is WaterNeed.UNKNOWN


def test_no_irrigation_excludes_deficit_crops_and_ranks_without_scores() -> None:
    evs = [
        _ev("aus_rice", (4, 16), (8, 19), 631, 1032),
        _ev("aman_rice", (8, 20), (11, 25), 631, 1118),
        _ev("boro_rice", (12, 3), (4, 10), 631, 167),
        _ev("lentil", (11, 30), (3, 1), None, None, None),
    ]
    r = generate_rotations(evs, has_irrigation=False, priorities=("soil_health", "income"))
    assert "boro_rice" in {c for c, _ in r.excluded}
    assert r.status is Status.OK and r.scenarios[0].has_pulse
    assert r.unsupported_priorities == ("income",)
    assert all("boro_rice" not in s.crops for s in r.scenarios)


def test_insufficient_evidence_when_nothing_fits() -> None:
    evs = [_ev("aman_rice", (7, 1), (11, 30)), _ev("boro_rice", (10, 1), (3, 30))]
    r = generate_rotations(evs, has_irrigation=True)
    assert r.status is Status.INSUFFICIENT_EVIDENCE and r.reasons


def test_gaez_zero_excludes_crop() -> None:
    evs = [_ev("wheat", (11, 15), (3, 10), gaez=(0, 0)), _ev("aman_rice", (7, 1), (11, 1))]
    r = generate_rotations(evs, has_irrigation=True)
    assert ("wheat", "GAEZ v5 index is 0 under both rain-fed and irrigated supply") in r.excluded


def test_calendar_contains_cross_year() -> None:
    boro = next(w for w in calendars_for_district("Sunamganj") if w.crop == "boro_rice")
    assert boro.contains(date(2025, 1, 15)) and not boro.contains(date(2025, 7, 15))
