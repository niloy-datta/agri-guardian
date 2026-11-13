"""SoilGrids, WoSIS, FAOSTAT, OpenTopography/terrain maths, Open-Meteo, registry.

Payloads mirror live responses; values are SYNTHETIC TEST DATA. Terrain
maths is checked against analytically known answers.
"""

import io
import math
import zipfile
from datetime import date, datetime
from pathlib import Path

import httpx
import numpy as np
import pytest
import tifffile

from app.core.config import Settings
from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.fao.faostat import FaostatClient, latest_by_element
from app.integrations.hub import IntegrationHub
from app.integrations.registry import INTEGRATIONS, Verification, is_configured
from app.integrations.soil.soilgrids import SoilGridsClient
from app.integrations.soil.wosis import WosisClient
from app.integrations.terrain.opentopography import (
    DemGrid,
    OpenTopographyClient,
    parse_aaigrid,
    slope_degrees,
    summarize_dem,
)
from app.integrations.weather.open_meteo import OpenMeteoClient
from tests.integrations.helpers import json_response, make_http

BBOX = (88.55, 24.32, 88.65, 24.42)


# ---------------------------------------------------------------- SoilGrids
def _soil(handler) -> SoilGridsClient:  # type: ignore[no-untyped-def]
    return SoilGridsClient(
        rest_url="https://rest.test/soilgrids/v2.0", wcs_url="https://maps.test/mapserv", http=make_http(handler)
    )


def _layer(name: str, d_factor: int, unit: str, mean: int | None) -> dict:
    return {
        "name": name,
        "unit_measure": {"d_factor": d_factor, "target_units": unit},
        "depths": [{"label": "0-5cm", "values": {"mean": mean}}],
    }


async def test_soilgrids_rest_scales_by_d_factor() -> None:
    body = {"properties": {"layers": [_layer("phh2o", 10, "-", 68), _layer("nitrogen", 100, "g/kg", 250)]}}
    result = await _soil(lambda r: json_response(body)).fetch_point(
        latitude=24.37, longitude=88.6, properties=("phh2o", "nitrogen"), depths=("0-5cm",)
    )
    by_prop = {v.property: v for v in result.values}
    assert by_prop["phh2o"].value == pytest.approx(6.8)
    assert by_prop["nitrogen"].value == pytest.approx(2.5)
    assert result.has_data is True


async def test_soilgrids_rest_null_means_no_data_not_zero() -> None:
    """Live finding: REST returned null for both Bangladesh points tried."""
    body = {"properties": {"layers": [_layer("phh2o", 10, "-", None)]}}
    result = await _soil(lambda r: json_response(body)).fetch_point(
        latitude=24.37, longitude=88.6, properties=("phh2o",), depths=("0-5cm",)
    )
    assert result.values[0].value is None and result.has_data is False


async def test_soilgrids_rest_repeats_property_and_depth_params() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return json_response({"properties": {"layers": []}})

    await _soil(handler).fetch_point(
        latitude=24.37, longitude=88.6, properties=("phh2o", "soc"), depths=("0-5cm", "5-15cm")
    )
    params = seen[0].url.params
    assert params.get_list("property") == ["phh2o", "soc"]
    assert params.get_list("depth") == ["0-5cm", "5-15cm"]


@pytest.mark.parametrize("prop,depth", [("ph;h2o", "0-5cm"), ("phh2o", "0-5")])
async def test_soilgrids_rejects_injection_like_names(prop: str, depth: str) -> None:
    with pytest.raises(IntegrationValidationError):
        await _soil(lambda r: json_response({})).fetch_wcs_geotiff(property=prop, depth=depth, bbox=BBOX)


def _tiff(values: list[list[int]]) -> bytes:
    buffer = io.BytesIO()
    tifffile.imwrite(buffer, np.array(values, dtype=np.int16))
    return buffer.getvalue()


async def test_soilgrids_wcs_stats_mask_verified_nodata_and_scale() -> None:
    # Live: phh2o raster is pH*10 int16 with 0 as no-data.
    tiff = _tiff([[70, 70, 0], [66, 0, 74]])
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, content=tiff, headers={"content-type": "image/tiff"})

    stats = await _soil(handler).fetch_wcs_stats(property="phh2o", depth="0-5cm", bbox=BBOX)
    assert stats.valid_pixels == 4 and stats.total_pixels == 6
    assert stats.mean == pytest.approx(7.0) and stats.minimum == pytest.approx(6.6)
    p = seen[0].url.params
    assert p["COVERAGEID"] == "phh2o_0-5cm_mean" and p["map"] == "/map/phh2o.map"
    assert p.get_list("SUBSET") == ["Lat(24.32,24.42)", "Long(88.55,88.65)"]


async def test_soilgrids_wcs_unverified_property_needs_explicit_d_factor() -> None:
    tiff = _tiff([[10, 20]])
    client = _soil(lambda r: httpx.Response(200, content=tiff))
    with pytest.raises(IntegrationValidationError, match="d_factor"):
        await client.fetch_wcs_stats(property="clay", depth="0-5cm", bbox=BBOX)
    stats = await client.fetch_wcs_stats(property="clay", depth="0-5cm", bbox=BBOX, d_factor=10)
    assert stats.mean == pytest.approx(1.5)  # no nodata masking assumed


async def test_soilgrids_wcs_error_page_is_not_decoded_as_tiff() -> None:
    client = _soil(lambda r: httpx.Response(200, text="<HTML>MapServer Message</HTML>"))
    with pytest.raises(IntegrationResponseError, match="TIFF"):
        await client.fetch_wcs_geotiff(property="phh2o", depth="0-5cm", bbox=BBOX)


async def test_soilgrids_wcs_rejects_country_sized_bbox() -> None:
    with pytest.raises(IntegrationValidationError, match="field-sized"):
        await _soil(lambda r: httpx.Response(200)).fetch_wcs_geotiff(
            property="phh2o", depth="0-5cm", bbox=(88.0, 20.0, 92.0, 26.0)
        )


# -------------------------------------------------------------------- WoSIS
async def test_wosis_bbox_filter_and_null_year() -> None:
    import json

    def handler(request: httpx.Request) -> httpx.Response:
        variables = json.loads(request.content)["variables"]
        assert variables["filter"]["latitude"] == {"greaterThanOrEqualTo": 24.0, "lessThanOrEqualTo": 25.0}
        return json_response({"data": {"wosisLatestProfiles": [
            {"profileId": 1121455, "profileCode": "BD0002", "datasetCode": "x", "year": None,
             "latitude": 24.5, "longitude": 88.75, "countryName": "Bangladesh",
             "wrbReferenceSoilGroup": None}
        ]}})  # fmt: skip

    client = WosisClient(graphql_url="https://g.test/graphql", http=make_http(handler))
    result = await client.search_profiles_in_bbox(bbox=(88.0, 24.0, 89.5, 25.0), first=5)
    assert result.profiles[0].profile_code == "BD0002" and result.profiles[0].year is None


async def test_wosis_graphql_errors_surface() -> None:
    client = WosisClient(
        graphql_url="https://g.test/graphql",
        http=make_http(lambda r: json_response({"errors": [{"message": "bad"}]})),
    )
    with pytest.raises(IntegrationResponseError, match="bad"):
        await client.search_profiles_in_bbox(bbox=(88.0, 24.0, 89.5, 25.0))


# ----------------------------------------------------------------- FAOSTAT
_HEADER = (
    "Area Code,Area Code (M49),Area,Item Code,Item Code (CPC),Item,Element Code,Element,"
    "Year Code,Year,Unit,Value,Flag,Note\n"
)


def _fao_zip(rows: list[str]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        z.writestr("Production_Crops_Livestock_E_All_Data_(Normalized).csv", _HEADER + "".join(rows))
        z.writestr("Production_Crops_Livestock_E_Flags.csv", "x\n")
    return buffer.getvalue()


def _fao_row(area: str, item: str, element: str, year: int, value: str, flag: str = "A") -> str:
    return f'16,"\'050",{area},27,"\'0113",{item},5412,{element},{year},{year},kg/ha,{value},{flag},\n'


def _fao(handler, token: str = "", cache_dir: Path | None = None) -> FaostatClient:  # type: ignore[no-untyped-def]
    return FaostatClient(
        api_url="https://fao.test/api/v1", bulk_catalog_url="https://fao.test/datasets_E.json",
        token=token, http=make_http(handler), cache_dir=cache_dir,
    )  # fmt: skip


def _fao_handler(zip_bytes: bytes, counter: dict | None = None):  # type: ignore[no-untyped-def]
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("datasets_E.json"):
            return json_response({"Datasets": {"Dataset": [
                {"DatasetCode": "QCL", "DatasetName": "Production", "FileLocation": "https://fao.test/qcl.zip",
                 "FileRows": 4, "FileSize": "1KB", "DateUpdate": "2025-12-31"}
            ]}})  # fmt: skip
        if counter is not None:
            counter["zip"] = counter.get("zip", 0) + 1
        return httpx.Response(200, content=zip_bytes)

    return handler


async def test_faostat_bulk_filters_strips_codes_and_keeps_missing_as_none() -> None:
    rows = [
        _fao_row("Bangladesh", "Rice", "Yield", 2022, "4980.4"),
        _fao_row("Bangladesh", "Rice", "Yield", 2023, "", "M"),
        _fao_row("Bangladesh", "Wheat", "Yield", 2022, "3000"),
        _fao_row("India", "Rice", "Yield", 2022, "4000"),
        _fao_row("Bangladesh", "Rice", "Yield", 2010, "4100"),
    ]
    client = _fao(_fao_handler(_fao_zip(rows)))
    result = await client.fetch_bulk_rows(
        dataset_code="QCL", areas=("Bangladesh",), items=("Rice",), elements=("Yield",), year_from=2020
    )
    assert [(o.year, o.value, o.flag) for o in result.observations] == [(2022, 4980.4, "A"), (2023, None, "M")]
    assert result.observations[0].area_code_m49 == "050" and result.observations[0].item_code_cpc == "0113"
    latest = latest_by_element(result.observations)
    assert latest["Yield"].year == 2022  # 2023 has no value, so it is not "latest"


async def test_faostat_bulk_uses_disk_cache(tmp_path: Path) -> None:
    counter: dict = {}
    client = _fao(_fao_handler(_fao_zip([_fao_row("Bangladesh", "Rice", "Yield", 2022, "1")]), counter), cache_dir=tmp_path)
    first = await client.fetch_bulk_rows(dataset_code="QCL", areas=("Bangladesh",))
    second = await client.fetch_bulk_rows(dataset_code="QCL", areas=("Bangladesh",))
    assert counter["zip"] == 1
    assert first.provenance.data_mode == "live" and second.provenance.data_mode == "cache"


async def test_faostat_unknown_dataset_and_missing_token() -> None:
    client = _fao(_fao_handler(b""))
    with pytest.raises(IntegrationValidationError):
        await client.fetch_bulk_rows(dataset_code="NOPE", areas=("Bangladesh",))
    with pytest.raises(IntegrationCredentialsMissingError):
        await client.query_data("QCL")


async def test_faostat_query_api_sends_bearer_when_configured() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["authorization"] == "Bearer T"
        return json_response({"data": []})

    assert await _fao(handler, token="T").query_data("QCL", area="16") == {"data": []}


# -------------------------------------------------------------- OpenTopo
def _aai(rows: list[list[float]], cellsize: float = 0.0003, yll: float = 0.0) -> str:
    header = (
        f"ncols {len(rows[0])}\nnrows {len(rows)}\nxllcorner 88.0\nyllcorner {yll}\n"
        f"cellsize {cellsize}\nNODATA_value -9999\n"
    )
    return header + "\n".join(" ".join(str(v) for v in r) for r in rows)


def test_slope_of_uniform_eastward_ramp_matches_analytic_value() -> None:
    # Elevation rises 1 m per cell eastward; cell width at the equator is
    # 0.0003 deg * 111320 m = 33.396 m, so slope = atan(1/33.396).
    rows = [[float(c) for c in range(6)] for _ in range(6)]
    grid = parse_aaigrid(_aai(rows, yll=0.0))
    slope = slope_degrees(grid)
    expected = math.degrees(math.atan(1 / (0.0003 * 111_320 * math.cos(math.radians(grid.center_latitude)))))
    interior = slope[1:-1, 1:-1]
    assert np.allclose(interior, expected, atol=1e-6)
    assert expected == pytest.approx(1.715, abs=0.01)
    assert np.isnan(slope[0, 0])  # edges undefined


def test_flat_dem_has_zero_slope_and_is_fully_flat() -> None:
    grid = parse_aaigrid(_aai([[5.0] * 5 for _ in range(5)]))
    summary = summarize_dem(grid)
    assert summary.slope_max_deg == 0.0 and summary.flat_fraction == 1.0
    assert summary.relief_m == 0.0 and summary.elevation_mean_m == 5.0


def test_aaigrid_nodata_becomes_nan_and_excluded_from_stats() -> None:
    rows = [[1.0, 1.0, 1.0, 1.0], [1.0, -9999, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]]
    summary = summarize_dem(parse_aaigrid(_aai(rows)))
    assert summary.valid_cells == 15 and summary.total_cells == 16
    assert summary.elevation_mean_m == 1.0


def test_aaigrid_wrong_value_count_and_tiny_grid_rejected() -> None:
    with pytest.raises(IntegrationResponseError, match="expected"):
        parse_aaigrid("ncols 3\nnrows 3\nxllcorner 0\nyllcorner 0\ncellsize 1\n1 2 3")
    with pytest.raises(IntegrationResponseError, match="too small"):
        summarize_dem(parse_aaigrid(_aai([[1.0, 2.0], [3.0, 4.0]])))


def test_dem_grid_dataclass_center_latitude() -> None:
    grid = DemGrid(elevation=np.zeros((10, 10)), xll=88.0, yll=24.0, cellsize_deg=0.001)
    assert grid.center_latitude == pytest.approx(24.005)


async def test_opentopography_requires_key_and_sends_aaigrid_request() -> None:
    def never(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no network without key")

    with pytest.raises(IntegrationCredentialsMissingError):
        await OpenTopographyClient(base_url="https://ot.test/API", api_key="", http=make_http(never)).fetch_dem(
            bbox=(88.6, 24.37, 88.62, 24.39)
        )

    def handler(request: httpx.Request) -> httpx.Response:
        p = request.url.params
        assert p["demtype"] == "COP30" and p["outputFormat"] == "AAIGrid" and p["API_Key"] == "K"
        return httpx.Response(200, text=_aai([[float(c) for c in range(5)] for _ in range(5)]))

    client = OpenTopographyClient(base_url="https://ot.test/API", api_key="K", http=make_http(handler))
    result = await client.fetch_dem(bbox=(88.6, 24.37, 88.62, 24.39))
    assert result.summary.slope_mean_deg > 0
    assert "K" not in result.provenance.source_url.replace("API_Key=***", "")


async def test_opentopography_rejects_huge_bbox_and_bad_demtype_and_error_body() -> None:
    client = OpenTopographyClient(
        base_url="https://ot.test/API", api_key="K", http=make_http(lambda r: httpx.Response(200, text="<error>x</error>"))
    )
    with pytest.raises(IntegrationValidationError, match="square degrees"):
        await client.fetch_dem(bbox=(88.0, 24.0, 89.0, 25.0))
    with pytest.raises(IntegrationValidationError, match="demtype"):
        await client.fetch_dem(bbox=(88.6, 24.37, 88.62, 24.39), demtype="NOPE")
    with pytest.raises(IntegrationResponseError, match="AAIGrid"):
        await client.fetch_dem(bbox=(88.6, 24.37, 88.62, 24.39))


# -------------------------------------------------------------- Open-Meteo
def _om(handler, api_key: str = "") -> OpenMeteoClient:  # type: ignore[no-untyped-def]
    return OpenMeteoClient(
        http=make_http(handler), forecast_url="https://om.test/v1/forecast",
        archive_url="https://om.test/v1/archive", flood_url="https://om.test/v1/flood", api_key=api_key,
    )  # fmt: skip


async def test_open_meteo_forecast_parses_arrays_units_and_snapped_grid() -> None:
    body = {
        "latitude": 24.3585, "longitude": 88.5608, "elevation": 23.0, "timezone": "Asia/Dhaka",
        "daily_units": {"time": "iso8601", "precipitation_sum": "mm"},
        "daily": {"time": ["2026-11-13", "2026-11-14"], "precipitation_sum": [0.0, None]},
    }  # fmt: skip
    result = await _om(lambda r: json_response(body)).forecast(
        latitude=24.37, longitude=88.6, daily=("precipitation_sum",), forecast_days=2
    )
    assert result.rows[0].time == date(2026, 11, 13)
    assert [r.values["precipitation_sum"] for r in result.rows] == [0.0, None]  # null stays None
    assert result.units == {"precipitation_sum": "mm"}
    assert result.grid_latitude == 24.3585 and result.requested_latitude == 24.37


async def test_open_meteo_hourly_rows_are_datetimes_and_api_key_passes() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return json_response({
            "latitude": 1.0, "longitude": 2.0,
            "hourly_units": {"time": "iso8601", "temperature_2m": "°C"},
            "hourly": {"time": ["2024-01-01T00:00"], "temperature_2m": [13.1]},
        })  # fmt: skip

    result = await _om(handler, api_key="SECRET").historical(
        latitude=24.37, longitude=88.6, start=date(2024, 1, 1), end=date(2024, 1, 1),
        daily=(), hourly=("temperature_2m",),
    )  # fmt: skip
    assert result.rows[0].time == datetime(2024, 1, 1, 0, 0)
    assert seen[0].url.params["apikey"] == "SECRET"
    assert "SECRET" not in result.provenance.source_url


async def test_open_meteo_flood_and_error_body_and_validation() -> None:
    flood = {
        "latitude": 24.375, "longitude": 88.625,
        "daily_units": {"time": "iso8601", "river_discharge": "m³/s"},
        "daily": {"time": ["2026-11-13"], "river_discharge": [0.09]},
    }
    result = await _om(lambda r: json_response(flood)).flood(latitude=24.37, longitude=88.6, forecast_days=1)
    assert result.rows[0].values["river_discharge"] == 0.09 and result.grid_latitude == 24.375

    with pytest.raises(IntegrationResponseError, match="bad variable"):
        await _om(lambda r: json_response({"error": True, "reason": "bad variable"})).forecast(
            latitude=24.37, longitude=88.6
        )
    client = _om(lambda r: json_response({}))
    with pytest.raises(IntegrationValidationError):
        await client.forecast(latitude=24.37, longitude=88.6, forecast_days=30)
    with pytest.raises(IntegrationValidationError):
        await client.forecast(latitude=24.37, longitude=88.6, daily=("rain,evil",))
    with pytest.raises(IntegrationValidationError):
        await client.historical(latitude=24.37, longitude=88.6, start=date(2024, 2, 1), end=date(2024, 1, 1))


async def test_open_meteo_mismatched_array_lengths_rejected() -> None:
    body = {
        "latitude": 1.0, "longitude": 2.0,
        "daily": {"time": ["2026-11-13", "2026-11-14"], "precipitation_sum": [0.0]},
    }
    with pytest.raises(IntegrationResponseError, match="length"):
        await _om(lambda r: json_response(body)).forecast(latitude=24.37, longitude=88.6)


# ------------------------------------------------------------- Registry/hub
def test_registry_lists_exactly_the_thirty_requested_integrations() -> None:
    assert [s.number for s in INTEGRATIONS] == list(range(1, 31))
    assert sum(1 for s in INTEGRATIONS if s.priority == "P0") == 8
    names = {s.name for s in INTEGRATIONS}
    assert "NASA POWER CMIP6 Projection API" in names and "OpenTopography Global DEM API" in names


def test_registry_never_claims_verified_for_credential_gated_only_services() -> None:
    by_number = {s.number: s for s in INTEGRATIONS}
    for number in (16, 17, 18, 23, 30):
        assert by_number[number].verification is Verification.UNVERIFIED
    assert by_number[5].verification is Verification.PARTIAL  # BD returns fill only
    assert by_number[26].verification is Verification.PARTIAL  # query API needs auth


def test_is_configured_reflects_settings() -> None:
    by_number = {s.number: s for s in INTEGRATIONS}
    empty = Settings(_env_file=None)
    assert is_configured(by_number[27], empty) is True  # keyless
    assert is_configured(by_number[16], empty) is False
    assert is_configured(by_number[30], empty) is False
    full = Settings(
        _env_file=None, copernicus_client_id="i", copernicus_client_secret="s", opentopography_api_key="k",
        nasa_earthdata_token="t", nasa_earthdata_username="u", nasa_earthdata_password="p",
    )  # fmt: skip
    assert all(is_configured(by_number[n], full) for n in (7, 8, 16, 30))


async def test_hub_wires_clients_and_honours_global_offline() -> None:
    hub = IntegrationHub(Settings(_env_file=None, integrations_offline=True))
    try:
        assert hub.open_meteo is hub.open_meteo  # cached
        with pytest.raises(Exception, match="offline"):
            await hub.open_meteo.forecast(latitude=24.37, longitude=88.6)
        with pytest.raises(IntegrationCredentialsMissingError):
            await hub.sentinel_hub.fetch_ndvi_raster(
                bbox=BBOX, start=date(2026, 10, 1), end=date(2026, 10, 2)
            )
    finally:
        await hub.aclose()
