"""Dataset catalogue, crop-calendar and farmer-profile tests (no network)."""

from __future__ import annotations

from datetime import date
from decimal import Decimal
from pathlib import Path

import httpx
import pytest

from app.integrations.common.errors import IntegrationValidationError
from app.integrations.datasets import DATASETS, Access, discover, get_dataset, integrations_for
from app.integrations.hub import IntegrationHub
from app.integrations.reference.crop_calendars import (
    BRRI_AMAN_HYV_TRANSPLANT,
    CropWindow,
    load_calendar_csv,
    rotation_conflicts,
)
from app.integrations.reference.farmer_profile import FarmerRotationProfile, Irrigation, Outcome
from app.integrations.registry import INTEGRATIONS

BBOX = (88.5, 24.3, 88.7, 24.45)


def test_catalogue_has_thirty_unique_datasets() -> None:
    assert [d.number for d in DATASETS] == list(range(1, 31))
    assert len({d.key for d in DATASETS}) == 30
    short = [d.cmr_short_name for d in DATASETS if d.cmr_short_name]
    assert len(short) == len(set(short))


def test_every_dataset_links_to_real_integrations_and_has_caveat() -> None:
    known = {i.number for i in INTEGRATIONS}
    for d in DATASETS:
        assert set(d.integrations) <= known, d.key
        assert d.caveat and d.use, d.key
        if d.access is Access.CMR:
            assert d.cmr_short_name and d.cmr_version, d.key
        if d.access is Access.STAC:
            assert d.stac, d.key
    assert "NASA POWER Daily API" in integrations_for(get_dataset(1))


def test_get_dataset_by_key_and_number() -> None:
    assert get_dataset("smap_l4").cmr_short_name == "SPL4SMGP"
    assert get_dataset(19).key == "imerg_late"
    with pytest.raises(KeyError):
        get_dataset("nope")


def _hub(handler: httpx.MockTransport) -> IntegrationHub:
    return IntegrationHub(http_client=httpx.AsyncClient(transport=handler))


async def test_discover_cmr_uses_catalogued_short_name() -> None:
    seen: list[httpx.Request] = []

    def handler(req: httpx.Request) -> httpx.Response:
        seen.append(req)
        return httpx.Response(200, json={"feed": {"entry": [
            {"id": "G1", "title": "t", "time_start": "2024-07-01T00:00:00Z",
             "links": [{"href": "https://x/a.h5"}]}]}})  # fmt: skip

    hits = await discover(_hub(httpx.MockTransport(handler)), "smap_l4",
                          bbox=BBOX, start=date(2024, 7, 1), end=date(2024, 7, 2))  # fmt: skip
    assert seen[0].url.params["short_name"] == "SPL4SMGP"
    assert hits[0].item_id == "G1" and hits[0].links == ["https://x/a.h5"]


async def test_discover_stac_uses_preferred_collection() -> None:
    def handler(req: httpx.Request) -> httpx.Response:
        assert b'"sentinel-2-l2a"' in req.content
        return httpx.Response(200, json={"type": "FeatureCollection", "features": [
            {"id": "S2X", "collection": "sentinel-2-l2a", "bbox": list(BBOX),
             "properties": {"datetime": "2024-07-03T04:00:00Z", "eo:cloud_cover": 12},
             "assets": {"red": {"href": "https://x/B04.tif"}}}], "links": []})  # fmt: skip

    hits = await discover(_hub(httpx.MockTransport(handler)), "s2_l2a",
                          bbox=BBOX, start=date(2024, 7, 1), end=date(2024, 7, 5))  # fmt: skip
    assert hits[0].item_id == "S2X" and hits[0].route == "stac:earth_search"


async def test_discover_rejects_reference_dataset() -> None:
    with pytest.raises(IntegrationValidationError):
        await discover(_hub(httpx.MockTransport(lambda r: httpx.Response(500))), "gaez_v5",
                       bbox=BBOX, start=date(2024, 1, 1), end=date(2024, 1, 2))  # fmt: skip


def test_brri_aman_window() -> None:
    w = BRRI_AMAN_HYV_TRANSPLANT
    assert w.verified and w.contains(date(2024, 7, 10)) and not w.contains(date(2024, 9, 1))


def _w(crop: str, start: tuple[int, int], end: tuple[int, int]) -> CropWindow:
    return CropWindow(crop, "s", "field_occupancy", start, end, "test", "https://example", False)


def test_rotation_conflicts_handle_year_wrap_and_missing_data() -> None:
    aman = _w("aman", (7, 1), (11, 15))
    mustard = _w("mustard", (11, 1), (2, 15))  # wraps the year
    boro = _w("boro", (1, 15), (5, 15))
    conflicts, missing = rotation_conflicts(["aman", "mustard", "boro", "lentil"],
                                            [aman, mustard, boro])  # fmt: skip
    pairs = {(c.first.crop, c.second.crop): c.overlap_days for c in conflicts}
    assert pairs[("aman", "mustard")] == 15
    assert pairs[("mustard", "boro")] == 32
    assert missing == ["lentil"]


def test_wrap_window_contains() -> None:
    m = _w("mustard", (11, 1), (2, 15))
    assert m.contains(date(2025, 1, 10)) and not m.contains(date(2025, 6, 1))


def test_invalid_window_rejected() -> None:
    with pytest.raises(ValueError):
        _w("x", (2, 30), (3, 1))


def test_load_calendar_csv_requires_source(tmp_path: Path) -> None:
    header = (
        "crop,season,stage,start_month,start_day,end_month,end_day,source,source_url,verified\n"
    )
    good = tmp_path / "ok.csv"
    good.write_text(header + "boro,boro,transplanting,1,1,2,15,DAE,https://dae.gov.bd,true\n")
    assert load_calendar_csv(good)[0].verified
    bad = tmp_path / "bad.csv"
    bad.write_text(header + "boro,boro,transplanting,1,1,2,15,DAE,,true\n")
    with pytest.raises(ValueError, match="source_url"):
        load_calendar_csv(bad)


def test_farmer_profile_consent_gates_explanations() -> None:
    p = FarmerRotationProfile(24.37, 88.6, ("aman_rice",), Irrigation.SUPPLEMENTARY,
                              Decimal("20000"), (Outcome.INCOME,))  # fmt: skip
    assert p.is_irrigated and p.explanation_context() == {}
    p2 = FarmerRotationProfile(24.37, 88.6, ("aman_rice",), Irrigation.NONE,
                               consent_to_personalise=True)  # fmt: skip
    assert p2.explanation_context()["irrigation"] == "none"


def test_farmer_profile_validation() -> None:
    with pytest.raises(IntegrationValidationError):
        FarmerRotationProfile(124.0, 88.6, (), Irrigation.NONE)
    with pytest.raises(ValueError):
        FarmerRotationProfile(24.0, 88.6, (), Irrigation.NONE, Decimal("-1"))
