"""Live smoke test for the 30 data-provider integrations.

    cd backend/api && .venv/Scripts/python scripts/integration_smoke.py
    ... --only soilgrids,open-meteo      # run a subset
    ... --list                           # show the catalogue and exit

Makes REAL network calls (unit tests never do). Keyless integrations run
always; credentialed ones run only when their settings are present and are
otherwise reported as SKIP with the missing setting - never as a pass.
Exit code is non-zero if any executed check fails.

Point used: Rajshahi (24.37N, 88.60E), the project's pilot district.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import time
from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import get_settings  # noqa: E402
from app.integrations.common.errors import (  # noqa: E402
    IntegrationCredentialsMissingError,
    IntegrationError,
)
from app.integrations.hub import IntegrationHub  # noqa: E402
from app.integrations.registry import INTEGRATIONS, is_configured  # noqa: E402

LAT, LON = 24.37, 88.60
BBOX = (88.55, 24.32, 88.65, 24.42)
POLYGON = {
    "type": "Polygon",
    "coordinates": [
        [[88.600, 24.370], [88.602, 24.370], [88.602, 24.372], [88.600, 24.372], [88.600, 24.370]]
    ],
}
TODAY = date.today()

Check = Callable[[IntegrationHub], Awaitable[str]]


async def power_hourly(h: IntegrationHub) -> str:
    pts = await h.power_extended.fetch_hourly(
        latitude=LAT, longitude=LON, start=date(2024, 1, 1), end=date(2024, 1, 1),
        parameters=("T2M",),
    )  # fmt: skip
    return f"{len(pts)} hourly points"


async def power_monthly(h: IntegrationHub) -> str:
    r = await h.power_extended.fetch_monthly(
        latitude=LAT, longitude=LON, start_year=2020, end_year=2021, parameters=("PRECTOTCORR",)
    )
    return f"{len(r.monthly)} months, annual years {sorted(r.annual)}"


async def power_climatology(h: IntegrationHub) -> str:
    r = await h.power_extended.fetch_climatology(
        latitude=LAT, longitude=LON, parameters=("T2M",)
    )
    return f"JUN mean T2M={r.monthly['T2M'][6]} C"


async def power_projection(h: IntegrationHub) -> str:
    r = await h.power_extended.fetch_projection(
        latitude=LAT, longitude=LON, start=date(2030, 6, 1), end=date(2030, 6, 2),
        parameters=("T2M",),
    )  # fmt: skip
    return f"has_coverage={r.has_coverage}"


async def cmr(h: IntegrationHub) -> str:
    cols, _ = await h.cmr.search_collections(short_name="GPM_3IMERGDF", page_size=1)
    return f"{cols[0].concept_id} v{cols[0].version}"


async def eonet(h: IntegrationHub) -> str:
    events, _ = await h.eonet.list_events(limit=3)
    return f"{len(events)} open events"


async def asf(h: IntegrationHub) -> str:
    scenes, _ = await h.asf.search_sentinel1(
        latitude=LAT, longitude=LON, start=TODAY - timedelta(days=60), end=TODAY, max_results=3
    )
    return f"{len(scenes)} S1 GRD scenes"


async def gibs(h: IntegrationHub) -> str:
    from app.integrations.nasa.gibs import TRUE_COLOR_LAYER, lat_lon_to_tile

    row, col = lat_lon_to_tile(LAT, LON, 6)
    data = await h.gibs.fetch_tile(
        layer=TRUE_COLOR_LAYER, day=date(2024, 10, 1), zoom=6, row=row, col=col
    )
    return f"tile {len(data)} bytes (JPEG={data[:2] == b'\xff\xd8'})"


async def harmony(h: IntegrationHub) -> str:
    caps = await h.harmony.get_capabilities("C2723754864-GES_DISC")
    return f"{caps.short_name} bbox_subsetting={caps.bbox_subsetting}"


async def appeears(h: IntegrationHub) -> str:
    products, _ = await h.appeears.list_products()
    layers = await h.appeears.list_layers("MOD13Q1.061")
    return f"{len(products)} products, MOD13Q1 has {len(layers)} layers"


async def cdse_stac(h: IntegrationHub) -> str:
    r = await h.cdse_stac.search(
        collection="sentinel-2-l2a", bbox=BBOX, start=_dt(30), end=_dt(0), limit=2
    )
    return f"{len(r.items)} items"


async def cdse_odata(h: IntegrationHub) -> str:
    products, _ = await h.cdse.search_products(
        collection="SENTINEL-2", latitude=LAT, longitude=LON, start=_dt(30),
        max_cloud_cover=60, top=2,
    )  # fmt: skip
    return f"{len(products)} products, first S3Path={products[0].s3_path if products else None}"


async def openeo(h: IntegrationHub) -> str:
    return f"{len(await h.cdse.list_openeo_collections())} collections"


async def earth_search(h: IntegrationHub) -> str:
    r = await h.earth_search.search(
        collection="sentinel-2-l2a", bbox=BBOX, start=_dt(30), end=_dt(0),
        max_cloud_cover=40, limit=2,
    )  # fmt: skip
    return f"{len(r.items)} items, cloud={[i.cloud_cover for i in r.items]}"


async def planetary(h: IntegrationHub) -> str:
    r = await h.planetary_computer.search(
        collection="sentinel-2-l2a", bbox=BBOX, start=_dt(30), end=_dt(0), limit=1
    )
    item = r.items[0]
    href = item.assets.get("B04") or next(iter(item.assets.values()))
    signed, expiry = await h.planetary_computer.sign_href(href)
    return f"{item.id} signed={'sig=' in signed or 'se=' in signed} expiry={expiry}"


async def soilgrids(h: IntegrationHub) -> str:
    stats = await h.soilgrids.fetch_wcs_stats(property="phh2o", depth="0-5cm", bbox=BBOX)
    # The REST point service is intermittently slow; its failure must not
    # hide the (separately verified) WCS result.
    try:
        point = await h.soilgrids.fetch_point(latitude=LAT, longitude=LON, properties=("phh2o",))
        rest = f"REST has_data={point.has_data}"
    except IntegrationError as exc:
        rest = f"REST unavailable ({type(exc).__name__})"
    return (
        f"WCS pH mean={stats.mean:.2f} over {stats.valid_pixels}/{stats.total_pixels} px; {rest}"
    )


async def wosis(h: IntegrationHub) -> str:
    r = await h.wosis.search_profiles_in_bbox(bbox=(88.0, 24.0, 89.5, 25.0), first=5)
    return f"{len(r.profiles)} profiles, e.g. {r.profiles[0].profile_code}"


async def faostat(h: IntegrationHub) -> str:
    ds = await h.faostat.list_bulk_datasets()
    return f"{len(ds)} bulk datasets (QCL present={any(d.code == 'QCL' for d in ds)})"


async def faostat_rows(h: IntegrationHub) -> str:
    r = await h.faostat.fetch_bulk_rows(
        dataset_code="QCL", areas=("Bangladesh",), items=("Rice",), elements=("Yield",),
        year_from=2020,
    )  # fmt: skip
    return f"{len(r.observations)} rows, latest={max(o.year for o in r.observations)}"


async def open_meteo(h: IntegrationHub) -> str:
    f = await h.open_meteo.forecast(latitude=LAT, longitude=LON, forecast_days=3)
    hist = await h.open_meteo.historical(
        latitude=LAT, longitude=LON, start=date(2024, 7, 1), end=date(2024, 7, 3)
    )
    flood = await h.open_meteo.flood(latitude=LAT, longitude=LON, forecast_days=2)
    return f"forecast {len(f.rows)}d, hist {len(hist.rows)}d, flood grid {flood.grid_latitude}"


# Credentialed checks: only run when configured.
async def sentinel_hub(h: IntegrationHub) -> str:
    ts = await h.sentinel_hub.fetch_ndvi_time_series(
        polygon=POLYGON, start=TODAY - timedelta(days=60), end=TODAY
    )
    return f"{len(ts.observations)} NDVI intervals, {ts.skipped_intervals} skipped"


async def opentopography(h: IntegrationHub) -> str:
    r = await h.opentopography.fetch_dem(bbox=(88.60, 24.37, 88.62, 24.39))
    return f"relief={r.summary.relief_m:.1f} m slope_mean={r.summary.slope_mean_deg:.2f} deg"


async def earth_engine(h: IntegrationHub) -> str:
    asset = await h.earth_engine.get_asset("COPERNICUS/S2_SR_HARMONIZED")
    return f"asset type={asset.get('type')}"


CHECKS: dict[str, tuple[Check, list[int]]] = {
    "power-hourly": (power_hourly, [2]),
    "power-monthly": (power_monthly, [3]),
    "power-climatology": (power_climatology, [4]),
    "power-projection": (power_projection, [5]),
    "cmr": (cmr, [6]),
    "harmony": (harmony, []),
    "appeears": (appeears, []),
    "gibs": (gibs, [11]),
    "asf": (asf, [12]),
    "eonet": (eonet, [13]),
    "cdse-stac": (cdse_stac, [14]),
    "cdse-odata": (cdse_odata, []),
    "sentinel-hub": (sentinel_hub, [16, 17, 18]),
    "openeo": (openeo, []),
    "earth-search": (earth_search, [21]),
    "planetary-computer": (planetary, [22]),
    "earth-engine": (earth_engine, [23]),
    "soilgrids": (soilgrids, [24]),
    "wosis": (wosis, [25]),
    "faostat-catalog": (faostat, [26]),
    "faostat-rows": (faostat_rows, [26]),
    "open-meteo": (open_meteo, [27, 28, 29]),
    "opentopography": (opentopography, [30]),
}


def _dt(days_ago: int) -> datetime:
    return datetime.now(UTC) - timedelta(days=days_ago)


async def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="", help="comma-separated check names")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        for spec in INTEGRATIONS:
            print(f"{spec.number:>2} [{spec.verification:<10}] {spec.name} ({spec.auth})")
        return 0

    settings = get_settings()
    wanted = {n.strip() for n in args.only.split(",") if n.strip()}
    by_number = {s.number: s for s in INTEGRATIONS}
    hub = IntegrationHub(settings)
    failures = 0
    try:
        for name, (check, numbers) in CHECKS.items():
            if wanted and name not in wanted:
                continue
            missing = [by_number[n].name for n in numbers if not is_configured(by_number[n], settings)]
            if missing:
                print(f"SKIP  {name:<20} credentials not configured for: {missing[0]}")
                continue
            started = time.monotonic()
            try:
                detail = await check(hub)
                print(f"PASS  {name:<20} {detail}  ({time.monotonic() - started:.1f}s)")
            except IntegrationCredentialsMissingError as exc:
                print(f"SKIP  {name:<20} {exc}")
            except (IntegrationError, KeyError, IndexError, ValueError) as exc:
                failures += 1
                print(f"FAIL  {name:<20} {type(exc).__name__}: {exc}")
    finally:
        await hub.aclose()
    print(f"\n{failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
