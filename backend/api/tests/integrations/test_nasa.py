"""NASA integrations: POWER extended, CMR/EONET/ASF, GIBS, Harmony, AppEEARS.

Payload shapes mirror live responses; values are SYNTHETIC TEST DATA.
"""

from datetime import date

import httpx
import pytest

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationValidationError,
)
from app.integrations.nasa.appeears import AppeearsClient
from app.integrations.nasa.discovery import AsfClient, CmrClient, EonetClient
from app.integrations.nasa.gibs import GibsClient, lat_lon_to_tile
from app.integrations.nasa.harmony import HarmonyClient
from app.integrations.nasa.power_extended import NasaPowerExtendedClient
from tests.integrations.helpers import json_response, make_http

POWER = "https://power.test"
SQUARE = {
    "type": "Polygon",
    "coordinates": [[[88.0, 24.0], [88.1, 24.0], [88.1, 24.1], [88.0, 24.1], [88.0, 24.0]]],
}


def _power(handler) -> NasaPowerExtendedClient:  # type: ignore[no-untyped-def]
    return NasaPowerExtendedClient(base_url=POWER, http=make_http(handler))


def _envelope(parameters: dict, units: dict, **header: object) -> dict:
    return {
        "type": "Feature",
        "properties": {"parameter": parameters},
        "header": {"fill_value": -999.0, "time_standard": "LST", **header},
        "parameters": {k: {"units": v} for k, v in units.items()},
    }


async def test_power_monthly_separates_annual_key_and_nulls_fill() -> None:
    body = _envelope(
        {"PRECTOTCORR": {"202001": 1.1, "202002": -999.0, "202013": 5.6}}, {"PRECTOTCORR": "mm/day"}
    )

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/temporal/monthly/point"
        assert request.url.params["start"] == "2020" and request.url.params["end"] == "2020"
        return json_response(body)

    result = await _power(handler).fetch_monthly(
        latitude=24.37, longitude=88.6, start_year=2020, end_year=2020, parameters=("PRECTOTCORR",)
    )
    assert result.monthly[(2020, 1)]["PRECTOTCORR"] == 1.1
    assert result.monthly[(2020, 2)]["PRECTOTCORR"] is None  # fill is not zero
    assert result.annual[2020]["PRECTOTCORR"] == 5.6
    assert (2020, 13) not in result.monthly
    assert result.units == {"PRECTOTCORR": "mm/day"}


async def test_power_climatology_maps_month_names_and_annual() -> None:
    months = dict(zip(
        ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"],
        range(12), strict=True))  # fmt: skip
    body = _envelope({"T2M": {**months, "ANN": 25.7}}, {"T2M": "C"}, range="25-year")
    result = await _power(lambda r: json_response(body)).fetch_climatology(
        latitude=24.37, longitude=88.6, parameters=("T2M",)
    )
    assert result.monthly["T2M"][1] == 0 and result.monthly["T2M"][12] == 11
    assert result.annual["T2M"] == 25.7
    assert result.period == "25-year"


async def test_power_hourly_parses_timestamps_in_order() -> None:
    body = _envelope({"T2M": {"2024010101": 12.0, "2024010100": 13.0}}, {"T2M": "C"})
    points = await _power(lambda r: json_response(body)).fetch_hourly(
        latitude=24.37, longitude=88.6, start=date(2024, 1, 1), end=date(2024, 1, 1),
        parameters=("T2M",),
    )  # fmt: skip
    assert [p.timestamp.hour for p in points] == [0, 1]
    assert points[0].values["T2M"] == 13.0


async def test_power_projection_reports_no_coverage_when_all_fill() -> None:
    """Live finding: Bangladesh points returned only -999 for CMIP6."""
    day = {"20300601": -999, "20300602": -999}
    body = _envelope(
        {"T2M": {"ssp126": day, "ssp245": day}}, {"T2M": "C"}, model="ensemble"
    )
    result = await _power(lambda r: json_response(body)).fetch_projection(
        latitude=24.37, longitude=88.6, start=date(2030, 6, 1), end=date(2030, 6, 2),
        parameters=("T2M",),
    )  # fmt: skip
    assert result.has_coverage is False
    assert result.values["ssp126"]["T2M"][date(2030, 6, 1)] is None


async def test_power_projection_with_data_has_coverage() -> None:
    body = _envelope({"T2M": {"ssp245": {"20300601": 22.2}}}, {"T2M": "C"}, model="ensemble")
    result = await _power(lambda r: json_response(body)).fetch_projection(
        latitude=40.0, longitude=-100.0, start=date(2030, 6, 1), end=date(2030, 6, 1),
        parameters=("T2M",), scenario="ssp245",
    )  # fmt: skip
    assert result.has_coverage is True


@pytest.mark.parametrize(
    "kwargs",
    [
        {"latitude": 95.0, "longitude": 88.0, "parameters": ("T2M",)},
        {"latitude": 24.0, "longitude": 88.0, "parameters": ()},
        {"latitude": 24.0, "longitude": 88.0, "parameters": ("t2m;drop",)},
        {"latitude": 24.0, "longitude": 88.0, "parameters": ("T2M",), "community": "XX"},
    ],
)
async def test_power_rejects_bad_requests_without_network(kwargs: dict) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no network")

    with pytest.raises(IntegrationValidationError):
        await _power(handler).fetch_climatology(**kwargs)


async def test_power_projection_rejects_hyphenated_model() -> None:
    with pytest.raises(IntegrationValidationError, match="CMIP6 model"):
        await _power(lambda r: json_response({})).fetch_projection(
            latitude=24.0, longitude=88.0, start=date(2030, 1, 1), end=date(2030, 1, 1),
            parameters=("T2M",), model="access-cm2",
        )  # fmt: skip


async def test_cmr_collections_and_granules() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/collections.json"):
            return json_response(
                {"feed": {"entry": [{"id": "C1-GES_DISC", "title": "GPM", "short_name": "G", "version_id": "07"}]}}
            )
        assert request.url.params["bounding_box"] == "88.5,24.3,88.7,24.4"
        assert request.url.params["temporal"] == "2024-07-01T00:00:00Z,2024-07-02T23:59:59Z"
        return json_response(
            {"feed": {"entry": [{"id": "G1", "title": "g", "time_start": "t0", "links": [{"href": "h"}]}]}}
        )

    cmr = CmrClient(base_url="https://cmr.test/search", http=make_http(handler))
    cols, _ = await cmr.search_collections(short_name="G")
    assert cols[0].concept_id == "C1-GES_DISC" and cols[0].version == "07"
    granules, _ = await cmr.search_granules(
        short_name="G", bbox=(88.5, 24.3, 88.7, 24.4), start=date(2024, 7, 1), end=date(2024, 7, 2)
    )
    assert granules[0].links == ["h"]
    with pytest.raises(IntegrationValidationError):
        await cmr.search_collections()


async def test_eonet_parses_point_and_converts_bbox_order() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["bbox"] == "88.0,25.0,89.0,24.0"  # UL then LR
        return json_response(
            {"events": [{
                "id": "E1", "title": "Flood", "closed": None,
                "categories": [{"id": "floods", "title": "Floods"}],
                "geometry": [{"date": "2026-11-12T00:00:00Z", "type": "Point", "coordinates": [88.5, 24.5]}],
            }]}
        )  # fmt: skip

    eonet = EonetClient(base_url="https://eonet.test/api/v3", http=make_http(handler))
    events, _ = await eonet.list_events(bbox=(88.0, 24.0, 89.0, 25.0))
    assert events[0].categories == ["floods"] and events[0].latest_coordinates == [88.5, 24.5]


async def test_asf_flattens_nested_list_and_parses_scene() -> None:
    scene = {
        "granuleName": "S1A_X", "startTime": "2026-11-03T12:12:20Z", "platform": "Sentinel-1D",
        "flightDirection": "ASCENDING", "polarization": "VV+VH", "processingLevel": "GRD_HD",
        "sizeMB": 900.5, "downloadUrl": "https://d/x.zip", "centerLat": "24.37", "centerLon": "88.03",
    }  # fmt: skip

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["intersectsWith"] == "point(88.6 24.37)"
        assert request.url.params["processingLevel"] == "GRD_HD"
        return json_response([[scene]])

    asf = AsfClient(base_url="https://asf.test", http=make_http(handler))
    scenes, _ = await asf.search_sentinel1(latitude=24.37, longitude=88.6)
    assert scenes[0].granule_name == "S1A_X" and scenes[0].center_lat == 24.37
    assert scenes[0].start_time is not None and scenes[0].start_time.year == 2026


def test_gibs_tile_math_and_urls() -> None:
    # By hand at zoom 6 (64x64 tiles): col = (88.6+180)/360*64 = 47.7 -> 47,
    # row = (1 - asinh(tan(24.37 deg))/pi)/2*64 = 27.5 -> 27.
    assert lat_lon_to_tile(24.37, 88.6, 6) == (27, 47)
    gibs = GibsClient(base_url="https://gibs.test", http=make_http(lambda r: json_response({})))
    url = gibs.tile_url(layer="L", day=date(2024, 10, 1), zoom=6, row=27, col=47)
    assert url == (
        "https://gibs.test/wmts/epsg3857/best/L/default/2024-10-01/"
        "GoogleMapsCompatible_Level9/6/27/47.jpg"
    )
    assert gibs.tile_url_template(layer="L", day=date(2024, 10, 1)).endswith("/{z}/{y}/{x}.jpg")
    with pytest.raises(IntegrationValidationError):
        lat_lon_to_tile(89.0, 0.0, 5)


async def test_harmony_capabilities_and_token_guard() -> None:
    caps_body = {
        "conceptId": "C1", "shortName": "GPM_3IMERGDF",
        "summary": {
            "subsetting": {"bbox": True, "temporal": True, "variable": True, "shape": False},
            "outputFormats": [{"name": "CSV"}],
        },
    }  # fmt: skip
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if request.url.path == "/capabilities":
            return json_response(caps_body)
        return httpx.Response(200, content=b"a,b\n1,2", headers={"content-type": "text/csv"})

    http = make_http(handler)
    caps = await HarmonyClient(base_url="https://h.test", token="", http=http).get_capabilities("C1")
    assert caps.bbox_subsetting and not caps.shape_subsetting and caps.output_formats == ["CSV"]

    with pytest.raises(IntegrationCredentialsMissingError):
        await HarmonyClient(base_url="https://h.test", token="", http=http).fetch_coverage_rangeset(
            collection_concept_id="C1", variable="precipitation", bbox=(88, 24, 89, 25),
            start=date(2024, 1, 1), end=date(2024, 1, 2),
        )  # fmt: skip

    cov = await HarmonyClient(base_url="https://h.test", token="tok", http=http).fetch_coverage_rangeset(
        collection_concept_id="C1", variable="precipitation", bbox=(88, 24, 89, 25),
        start=date(2024, 1, 1), end=date(2024, 1, 2),
    )  # fmt: skip
    assert cov.content == b"a,b\n1,2"
    last = seen[-1]
    assert last.headers["authorization"] == "Bearer tok"
    assert last.url.params.get_list("subset")[0] == "lat(24:25)"


async def test_appeears_products_login_and_task_bodies() -> None:
    bodies: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path.endswith("/product"):
            return json_response(
                [{"Product": "MOD13Q1", "Version": "061", "Platform": "Terra", "Available": True}]
            )
        if path.endswith("/login"):
            assert request.headers["authorization"].startswith("Basic ")
            return json_response({"token": "T", "token_type": "Bearer"})
        if path.endswith("/task") and request.method == "POST":
            assert request.headers["authorization"] == "Bearer T"
            import json

            bodies.append(json.loads(request.content))
            return json_response({"task_id": "abc", "status": "pending"})
        return json_response({"task_id": "abc", "status": "done"})

    client = AppeearsClient(
        base_url="https://ap.test/api", username="u", password="p", http=make_http(handler)
    )
    products, _ = await client.list_products()
    assert products[0].product_id == "MOD13Q1.061"

    layers = [("MOD13Q1.061", "_250m_16_days_NDVI")]
    task = await client.submit_area_task(
        name="field", polygon=SQUARE, start=date(2024, 6, 1), end=date(2024, 6, 30), layers=layers
    )
    assert task.task_id == "abc"
    area = bodies[0]
    assert area["task_type"] == "area"
    assert area["params"]["dates"] == [{"startDate": "06-01-2024", "endDate": "06-30-2024"}]
    assert area["params"]["geo"]["features"][0]["geometry"] == SQUARE

    await client.submit_point_task(
        name="pt", points=[("p1", 24.37, 88.6)], start=date(2024, 6, 1), end=date(2024, 6, 2),
        layers=layers,
    )  # fmt: skip
    assert bodies[1]["params"]["coordinates"][0]["latitude"] == 24.37
    assert (await client.get_task("abc")).status == "done"


async def test_appeears_task_without_login_fails_before_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no network")

    client = AppeearsClient(base_url="https://ap.test/api", username="", password="", http=make_http(handler))
    with pytest.raises(IntegrationCredentialsMissingError):
        await client.submit_area_task(
            name="x", polygon=SQUARE, start=date(2024, 1, 1), end=date(2024, 1, 2),
            layers=[("MOD13Q1.061", "l")],
        )  # fmt: skip
