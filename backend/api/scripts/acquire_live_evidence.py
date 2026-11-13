"""Acquire REAL observations / discovery results for the 30 datasets and
record them as evidence (docs/evidence/live_acquisition.json).

    cd backend/api && uv run python scripts/acquire_live_evidence.py

Makes live network calls. Each dataset gets one of:
  ACQUIRED   real values downloaded and parsed (sample values recorded)
  DISCOVERED live catalogue/search returned real granules or scenes, but
             the data itself was not downloaded (usually needs credentials)
  BLOCKED    a credential/permission is missing - the exact one is named
  NO_DATA    the service answered but returned no usable values
  FAILED     the call errored (message recorded)
Nothing here is mocked; no synthetic value is ever written.
"""

from __future__ import annotations

import asyncio
import json
import sys
import traceback
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402
from app.integrations.datasets import DATASETS, Access, discover  # noqa: E402
from app.integrations.hub import IntegrationHub  # noqa: E402
from app.integrations.nasa.client import NasaPowerClient  # noqa: E402
from app.integrations.reference.bd_locations import get_district  # noqa: E402

# One representative district per division (GeoNames district centroids).
DIVISION_POINTS = ("Rajshahi", "Dhaka", "Chattogram", "Khulna", "Barishal", "Sylhet",
                   "Rangpur", "Mymensingh")  # fmt: skip
EXTRA_POINTS = ("Sunamganj", "Satkhira")
BD_BBOX = (88.0, 20.6, 92.7, 26.7)
OUT = Path(__file__).resolve().parents[3] / "docs" / "evidence" / "live_acquisition.json"


def _bbox_around(lat: float, lon: float, d: float = 0.02) -> tuple[float, float, float, float]:
    return (lon - d, lat - d, lon + d, lat + d)


async def power_daily(s: Any) -> dict[str, Any]:
    client = NasaPowerClient(base_url=s.nasa_power_base_url, timeout_seconds=60)
    out = {}
    try:
        for name in DIVISION_POINTS + EXTRA_POINTS:
            lat, lon = get_district(name).centroid
            r = await client.fetch_daily_point(latitude=lat, longitude=lon,
                                               start=date(2024, 6, 1), end=date(2024, 7, 31))  # fmt: skip
            rain = [x.precipitation_mm for x in r.records if x.precipitation_mm is not None]
            out[name] = {"lat": lat, "lon": lon, "days": len(r.records),
                         "rain_total_mm_jun_jul_2024": round(sum(rain), 1),
                         "missing_days": len(r.records) - len(rain),
                         "first": [str(r.records[0].date), r.records[0].precipitation_mm,
                                   r.records[0].tmax_c, r.records[0].tmin_c]}  # fmt: skip
    finally:
        await client.aclose()
    return {"status": "ACQUIRED", "points": out}


async def power_monthly(h: IntegrationHub) -> dict[str, Any]:
    out = {}
    for name in DIVISION_POINTS:
        lat, lon = get_district(name).centroid
        r = await h.power_extended.fetch_monthly(latitude=lat, longitude=lon, start_year=2023,
                                                 end_year=2024, parameters=("PRECTOTCORR", "T2M_MAX"))  # fmt: skip
        jul = r.monthly.get((2024, 7), {})
        out[name] = {"months": len(r.monthly), "2024-07": jul, "units": r.units}
    return {"status": "ACQUIRED", "points": out}


async def power_cmip6(h: IntegrationHub) -> dict[str, Any]:
    out = {}
    for name in ("Rajshahi", "Sylhet", "Khulna"):
        lat, lon = get_district(name).centroid
        r = await h.power_extended.fetch_projection(latitude=lat, longitude=lon,
                                                    start=date(2040, 1, 1), end=date(2040, 1, 31),
                                                    parameters=("PRECTOTCORR",))  # fmt: skip
        out[name] = {"has_coverage": r.has_coverage, "model": r.model}
    covered = any(v["has_coverage"] for v in out.values())
    return {"status": "ACQUIRED" if covered else "NO_DATA", "points": out}


async def soilgrids(h: IntegrationHub) -> dict[str, Any]:
    out = {}
    for name in DIVISION_POINTS + EXTRA_POINTS:
        lat, lon = get_district(name).centroid
        props = {}
        for prop in ("phh2o", "soc", "nitrogen"):  # the props with verified d_factors
            st = await h.soilgrids.fetch_wcs_stats(property=prop, depth="0-5cm",
                                                   bbox=_bbox_around(lat, lon))  # fmt: skip
            props[prop] = {"mean": st.mean, "valid": st.valid_pixels, "total": st.total_pixels,
                           "d_factor": st.d_factor}  # fmt: skip
        out[name] = props
    return {"status": "ACQUIRED", "points": out}


async def faostat(h: IntegrationHub) -> dict[str, Any]:
    rows = await h.faostat.fetch_bulk_rows(dataset_code="QCL", areas=("Bangladesh",),
                                           items=("Rice", "Lentils, dry", "Mustard seed",
                                                  "Wheat", "Maize (corn)"))  # fmt: skip
    rows = rows.observations
    top = max((r.year for r in rows), default=None)
    latest = [r for r in rows if r.year == top]
    return {"status": "ACQUIRED" if rows else "NO_DATA", "rows": len(rows),
            "latest_year_sample": [repr(r)[:220] for r in latest[:10]]}  # fmt: skip


async def discovery(h: IntegrationHub, key: str) -> dict[str, Any]:
    lat, lon = get_district("Rajshahi").centroid
    hits = await discover(h, key, bbox=_bbox_around(lat, lon, 0.1),
                          start=date(2024, 1, 1), end=date(2024, 12, 31), limit=5)  # fmt: skip
    return {"status": "DISCOVERED" if hits else "NO_DATA", "hits": len(hits),
            "sample": [{"id": x.item_id, "start": x.start, "link": (x.links or [None])[0]}
                       for x in hits[:3]]}  # fmt: skip


async def asf(h: IntegrationHub) -> dict[str, Any]:
    lat, lon = get_district("Sylhet").centroid
    res = await h.asf.search_sentinel1(latitude=lat, longitude=lon,
                                       start=date(2024, 7, 1), end=date(2024, 7, 31))  # fmt: skip
    scenes = res[0] if isinstance(res, tuple) else res
    return {"status": "DISCOVERED" if scenes else "NO_DATA", "hits": len(scenes),
            "sample": [s.granule_name for s in scenes[:3]]}  # fmt: skip


async def main() -> int:
    s = get_settings()
    hub = IntegrationHub(s)
    creds = {
        "earthdata_token": bool(s.nasa_earthdata_token),
        "earthdata_login": bool(s.nasa_earthdata_username and s.nasa_earthdata_password),
        "copernicus_oauth": bool(s.copernicus_client_id and s.copernicus_client_secret),
        "faostat_token": bool(s.faostat_token),
    }
    jobs: dict[int, Any] = {
        1: power_daily(s), 20: power_monthly(hub), 21: power_cmip6(hub), 5: soilgrids(hub),
        9: faostat(hub), 29: asf(hub),
    }  # fmt: skip
    for d in DATASETS:
        if d.number not in jobs and (d.access is Access.CMR or d.stac):
            jobs[d.number] = discovery(hub, d.key)
    results: dict[str, Any] = {}
    try:
        for number in sorted(jobs):
            d = DATASETS[number - 1]
            try:
                results[f"{number:02d}"] = {"key": d.key, **await jobs[number]}
            except Exception as exc:  # recorded, never hidden
                results[f"{number:02d}"] = {"key": d.key, "status": "FAILED",
                                            "error": f"{type(exc).__name__}: {exc}"[:500],
                                            "trace": traceback.format_exc()[-800:]}  # fmt: skip
            print(f"{number:02d} {d.key:22s} {results[f'{number:02d}']['status']}", flush=True)
    finally:
        await hub.aclose()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"generated_at": datetime.now(UTC).isoformat(),
                               "credentials_present": creds, "results": results},
                              indent=2, default=str), encoding="utf-8")  # fmt: skip
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
