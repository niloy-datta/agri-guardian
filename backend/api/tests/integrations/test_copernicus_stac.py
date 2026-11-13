"""CDSE OData/openEO/S3 locator, Sentinel Hub builders + parser, STAC clients.

Sentinel Hub response fixtures follow the *documented* Statistical API
shape (no credentials were available to capture a live one) - see the
module docstring of `sentinel_hub.py`. Values are SYNTHETIC.
"""

import json
from datetime import UTC, date, datetime

import httpx
import pytest

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.oauth import ClientCredentialsTokenSource
from app.integrations.copernicus.cdse import CdseClient, CdseS3Locator
from app.integrations.copernicus.sentinel_hub import (
    SentinelHubClient,
    parse_ndvi_statistics,
)
from app.integrations.stac.client import CdseStacClient, PlanetaryComputerStacClient, StacClient
from tests.integrations.helpers import json_response, make_http

SQUARE = {
    "type": "Polygon",
    "coordinates": [[[88.0, 24.0], [88.1, 24.0], [88.1, 24.1], [88.0, 24.1], [88.0, 24.0]]],
}
START = datetime(2026, 10, 1, tzinfo=UTC)
END = datetime(2026, 11, 1, tzinfo=UTC)
BBOX = (88.5, 24.3, 88.7, 24.4)


def _cdse(handler, tokens=None) -> CdseClient:  # type: ignore[no-untyped-def]
    return CdseClient(
        odata_url="https://cat.test/odata/v1",
        download_url="https://dl.test/odata/v1",
        openeo_url="https://openeo.test/openeo/1.2",
        http=make_http(handler),
        token_source=tokens,
    )


async def test_cdse_odata_builds_verified_filter_and_parses_products() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        flt = request.url.params["$filter"]
        assert "Collection/Name eq 'SENTINEL-2'" in flt
        assert "OData.CSC.Intersects(area=geography'SRID=4326;POINT(88.6 24.37)')" in flt
        assert "ContentDate/Start gt 2026-10-01T00:00:00.000Z" in flt
        assert "contains(Name,'MSIL2A')" in flt
        assert "Value lt 40.00" in flt
        assert request.url.params["$orderby"] == "ContentDate/Start desc"
        return json_response(
            {"value": [{
                "Id": "abc", "Name": "S2B_MSIL2A.SAFE", "ContentLength": 1183019053, "Online": True,
                "S3Path": "/eodata/Sentinel-2/MSI/L2A/2026/11/09/S2B_MSIL2A.SAFE",
                "ContentDate": {"Start": "2026-11-09T04:40:09.024Z", "End": "x"},
            }]}
        )  # fmt: skip

    products, _ = await _cdse(handler).search_products(
        collection="SENTINEL-2", latitude=24.37, longitude=88.6, start=START, max_cloud_cover=40
    )
    assert products[0].id == "abc" and products[0].online is True
    assert products[0].content_start is not None and products[0].content_start.day == 9


async def test_cdse_rejects_unknown_collection_and_quote_injection() -> None:
    client = _cdse(lambda r: json_response({"value": []}))
    with pytest.raises(IntegrationValidationError):
        await client.search_products(collection="DROP", latitude=24, longitude=88, start=START)
    with pytest.raises(IntegrationValidationError):
        await client.search_products(
            collection="SENTINEL-2", latitude=24, longitude=88, start=START,
            name_contains="x') or ('1'='1",
        )  # fmt: skip


async def test_cdse_download_requires_oauth_client() -> None:
    client = _cdse(lambda r: httpx.Response(200, content=b"zip"))
    assert client.download_url("abc") == "https://dl.test/odata/v1/Products(abc)/$value"
    with pytest.raises(IntegrationCredentialsMissingError):
        await client.download_product("abc")


async def test_cdse_download_sends_bearer_token() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if "token" in request.url.path:
            return json_response({"access_token": "TOK", "expires_in": 600})
        return httpx.Response(200, content=b"zipbytes")

    tokens = ClientCredentialsTokenSource(
        http=make_http(handler), token_url="https://auth.test/token", client_id="i", client_secret="s"
    )
    data = await _cdse(handler, tokens).download_product("abc")
    assert data == b"zipbytes"
    assert seen[-1].headers["authorization"] == "Bearer TOK"


async def test_openeo_collections() -> None:
    body = {"collections": [{"id": "SENTINEL2_L2A"}, {"id": "SENTINEL1_GRD"}]}
    assert await _cdse(lambda r: json_response(body)).list_openeo_collections() == [
        "SENTINEL2_L2A",
        "SENTINEL1_GRD",
    ]


def test_s3_locator_splits_bucket_and_key() -> None:
    loc = CdseS3Locator(endpoint_url="https://eodata.test/").locate(
        "/eodata/Sentinel-2/MSI/L2A/2026/11/09/X.SAFE"
    )
    assert (loc.bucket, loc.key) == ("eodata", "Sentinel-2/MSI/L2A/2026/11/09/X.SAFE")
    assert loc.endpoint == "https://eodata.test"
    with pytest.raises(IntegrationValidationError):
        CdseS3Locator(endpoint_url="https://e").locate("/other/x")


def _hub(handler, with_tokens: bool = True) -> SentinelHubClient:  # type: ignore[no-untyped-def]
    http = make_http(handler)
    tokens = (
        ClientCredentialsTokenSource(
            http=http, token_url="https://auth.test/token", client_id="i", client_secret="s"
        )
        if with_tokens
        else None
    )
    return SentinelHubClient(base_url="https://sh.test", token_source=tokens, http=http)


def test_sentinel_hub_ndvi_request_masks_clouds_and_uses_field_polygon() -> None:
    hub = _hub(lambda r: json_response({}))
    req = hub.build_ndvi_statistics_request(
        polygon=SQUARE, start=date(2026, 10, 1), end=date(2026, 10, 31), interval_days=5
    )
    assert req["input"]["bounds"]["geometry"] == SQUARE
    assert req["aggregation"]["aggregationInterval"] == {"of": "P5D"}
    assert req["input"]["data"][0]["type"] == "sentinel-2-l2a"
    script = req["aggregation"]["evalscript"]
    assert "SCL" in script and "dataMask" in script
    for scl_class in ("3", "8", "9", "10"):
        assert scl_class in script.split("indexOf")[0]
    proc = hub.build_ndvi_process_request(bbox=BBOX, start=date(2026, 10, 1), end=date(2026, 10, 31))
    assert proc["input"]["bounds"]["bbox"] == list(BBOX)
    assert proc["output"]["responses"][0]["format"]["type"] == "image/tiff"


def test_sentinel_hub_validates_inputs() -> None:
    hub = _hub(lambda r: json_response({}))
    with pytest.raises(IntegrationValidationError):
        hub.build_ndvi_statistics_request(polygon=SQUARE, start=date(2026, 11, 1), end=date(2026, 10, 1))
    with pytest.raises(IntegrationValidationError):
        hub.build_ndvi_process_request(bbox=BBOX, start=date(2026, 10, 1), end=date(2026, 10, 2), width=0)


def _stats(mean, sample, no_data, start="2026-10-01T00:00:00Z", end="2026-10-06T00:00:00Z") -> dict:  # type: ignore[no-untyped-def]
    return {
        "interval": {"from": start, "to": end},
        "outputs": {"ndvi": {"bands": {"B0": {"stats": {
            "min": 0.1, "max": 0.9, "mean": mean, "stDev": 0.05,
            "sampleCount": sample, "noDataCount": no_data,
        }}}}},
    }  # fmt: skip


def test_parse_ndvi_statistics_skips_fully_masked_intervals_not_zero() -> None:
    payload = {"data": [_stats(0.62, 100, 10), _stats("NaN", 100, 100), _stats(0.5, 100, 100)]}
    observations, skipped = parse_ndvi_statistics(payload)
    assert len(observations) == 1 and skipped == 2
    assert observations[0].mean == 0.62
    assert observations[0].valid_fraction == pytest.approx(0.9)


def test_parse_ndvi_statistics_rejects_malformed() -> None:
    with pytest.raises(IntegrationResponseError):
        parse_ndvi_statistics({"nope": 1})
    with pytest.raises(IntegrationResponseError):
        parse_ndvi_statistics({"data": [{"interval": {}}]})


async def test_sentinel_hub_statistics_end_to_end_with_bearer() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if "token" in request.url.path:
            return json_response({"access_token": "TOK", "expires_in": 600})
        assert request.url.path == "/api/v1/statistics"
        assert request.headers["authorization"] == "Bearer TOK"
        assert json.loads(request.content)["calculations"] == {"default": {}}
        return json_response({"data": [_stats(0.4, 50, 5)], "status": "OK"})

    series = await _hub(handler).fetch_ndvi_time_series(
        polygon=SQUARE, start=date(2026, 10, 1), end=date(2026, 10, 6)
    )
    assert series.observations[0].mean == 0.4 and series.skipped_intervals == 0


async def test_sentinel_hub_without_credentials_fails_before_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("no network")

    with pytest.raises(IntegrationCredentialsMissingError):
        await _hub(handler, with_tokens=False).fetch_ndvi_time_series(
            polygon=SQUARE, start=date(2026, 10, 1), end=date(2026, 10, 6)
        )


async def test_sentinel_hub_catalog_search() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if "token" in request.url.path:
            return json_response({"access_token": "T", "expires_in": 600})
        body = json.loads(request.content)
        assert body["filter"] == "eo:cloud_cover < 30.0" and body["collections"] == ["sentinel-2-l2a"]
        return json_response({"features": [
            {"id": "S2A_1", "properties": {"datetime": "2026-11-09T04:40:09Z", "eo:cloud_cover": 4.1}}
        ]})  # fmt: skip

    scenes = await _hub(handler).search_catalog(
        polygon=SQUARE, start=date(2026, 10, 1), end=date(2026, 11, 1), max_cloud_cover=30.0
    )
    assert scenes[0].id == "S2A_1" and scenes[0].cloud_cover == 4.1


def _feature(item_id: str, cloud: float | None) -> dict:
    props: dict = {"datetime": "2026-11-09T04:52:00.901000Z"}
    if cloud is not None:
        props["eo:cloud_cover"] = cloud
    return {
        "id": item_id, "collection": "sentinel-2-l2a", "bbox": [88.0, 24.0, 89.0, 25.0],
        "properties": props, "assets": {"B04": {"href": "https://a/b04.tif"}, "meta": {}},
    }  # fmt: skip


async def test_stac_post_search_pages_follow_post_next_link_and_filter_cloud() -> None:
    bodies: list[dict] = []

    def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        bodies.append(body)
        if "page" not in body:
            return json_response({
                "features": [_feature("a", 4.0), _feature("b", 80.0)],
                "links": [{"rel": "next", "method": "POST", "href": "https://s.test/search",
                           "body": {**body, "page": 2}}],
            })  # fmt: skip
        return json_response({"features": [_feature("c", 10.0)], "links": []})

    client = StacClient(provider="ES", base_url="https://s.test", http=make_http(handler))
    result = await client.search(
        collection="sentinel-2-l2a", bbox=BBOX, start=START, end=END, max_cloud_cover=30, limit=10
    )
    assert [i.id for i in result.items] == ["a", "c"]  # 'b' (80%) filtered client-side
    assert bodies[0]["query"] == {"eo:cloud_cover": {"lt": 30}}
    assert bodies[0]["datetime"] == "2026-10-01T00:00:00Z/2026-11-01T00:00:00Z"
    assert result.items[0].assets == {"B04": "https://a/b04.tif"}  # asset without href dropped
    assert result.truncated is False


async def test_stac_limit_truncates_and_flags() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return json_response({"features": [_feature("a", 1), _feature("b", 2)], "links": []})

    client = StacClient(provider="ES", base_url="https://s.test", http=make_http(handler))
    result = await client.search(collection="c", bbox=BBOX, start=START, end=END, limit=1)
    assert [i.id for i in result.items] == ["a"] and result.truncated is True


async def test_cdse_stac_uses_collection_items_get_route() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.method == "GET"
        assert request.url.path == "/stac/collections/sentinel-2-l2a/items"
        assert request.url.params["bbox"] == "88.5,24.3,88.7,24.4"
        return json_response({"features": [_feature("a", None)], "links": []})

    client = CdseStacClient(provider="CDSE", base_url="https://s.test/stac", http=make_http(handler))
    result = await client.search(collection="sentinel-2-l2a", bbox=BBOX, start=START, end=END)
    assert result.items[0].cloud_cover is None


async def test_planetary_computer_sign_href() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.params["href"] == "https://blob/x.tif"
        return json_response({"href": "https://blob/x.tif?sig=abc", "msft:expiry": "2026-11-13T07:00:00Z"})

    client = PlanetaryComputerStacClient(
        base_url="https://pc.test", sas_url="https://pc.test/sas", http=make_http(handler)
    )
    signed, expiry = await client.sign_href("https://blob/x.tif")
    assert signed.endswith("sig=abc") and expiry == "2026-11-13T07:00:00Z"


async def test_stac_rejects_bad_bbox_and_reversed_dates() -> None:
    client = StacClient(provider="ES", base_url="https://s.test", http=make_http(lambda r: json_response({})))
    with pytest.raises(IntegrationValidationError):
        await client.search(collection="c", bbox=(89, 24, 88, 25), start=START, end=END)
    with pytest.raises(IntegrationValidationError):
        await client.search(collection="c", bbox=BBOX, start=END, end=START)
