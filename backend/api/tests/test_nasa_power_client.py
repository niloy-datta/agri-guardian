"""Unit tests for NasaPowerClient against a mocked transport.

No live NASA network call happens anywhere in this file - every request
is served by `httpx.MockTransport`. The response shape used here
(properties.parameter, header.fill_value, header.time_standard,
parameters.<name>.units) mirrors a real NASA POWER Daily Point response
captured during this phase's development (see
`app/integrations/nasa/client.py`'s module docstring), but the specific
values are SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS.
"""

from datetime import date

import httpx
import pytest

from app.integrations.nasa.client import (
    DAILY_POINT_ENDPOINT,
    NasaPowerClient,
    NasaPowerRequestError,
    NasaPowerResponseError,
    NasaPowerValidationError,
)

FILL_VALUE = -999.0


def _synthetic_power_payload(
    *,
    precip: dict[str, float],
    tmax: dict[str, float],
    tmin: dict[str, float],
    time_standard: str = "LST",
) -> dict:
    """SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS."""
    return {
        "properties": {
            "parameter": {
                "PRECTOTCORR": precip,
                "T2M_MAX": tmax,
                "T2M_MIN": tmin,
            }
        },
        "header": {
            "title": "NASA/POWER Source Native Resolution Daily Data",
            "api": {"version": "v2.10.0", "name": "POWER Daily API"},
            "sources": ["MERRA2", "POWER"],
            "fill_value": FILL_VALUE,
            "time_standard": time_standard,
            "start": "20200101",
            "end": "20200103",
        },
        "parameters": {
            "PRECTOTCORR": {"units": "mm/day", "longname": "Precipitation Corrected"},
            "T2M_MAX": {"units": "C", "longname": "Temperature at 2 Meters Maximum"},
            "T2M_MIN": {"units": "C", "longname": "Temperature at 2 Meters Minimum"},
        },
        "messages": [],
    }


def _client_with_transport(handler) -> NasaPowerClient:
    http_client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return NasaPowerClient(
        base_url="https://power.larc.nasa.gov", timeout_seconds=5.0, http_client=http_client
    )


async def test_requests_the_correct_daily_endpoint() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["url"] = request.url
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0, "20200102": 2.0, "20200103": 3.0},
                tmax={"20200101": 30.0, "20200102": 31.0, "20200103": 29.0},
                tmin={"20200101": 20.0, "20200102": 21.0, "20200103": 19.0},
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 3)
        )
    finally:
        await client.aclose()

    assert captured["url"].path == DAILY_POINT_ENDPOINT


async def test_requests_community_ag_and_json_format() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["params"] = dict(request.url.params)
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0}, tmax={"20200101": 30.0}, tmin={"20200101": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    finally:
        await client.aclose()

    assert captured["params"]["community"] == "AG"
    assert captured["params"]["format"] == "JSON"


async def test_requests_explicit_lst_time_standard() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["params"] = dict(request.url.params)
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0}, tmax={"20200101": 30.0}, tmin={"20200101": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    finally:
        await client.aclose()

    assert captured["params"]["time-standard"] == "LST"


async def test_requests_correct_lat_lon_and_date_format() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["params"] = dict(request.url.params)
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200105": 1.0}, tmax={"20200105": 30.0}, tmin={"20200105": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 5), end=date(2020, 1, 5)
        )
    finally:
        await client.aclose()

    assert captured["params"]["latitude"] == "24.36"
    assert captured["params"]["longitude"] == "90.35"
    assert captured["params"]["start"] == "20200105"
    assert captured["params"]["end"] == "20200105"


async def test_requested_parameters_passed_correctly() -> None:
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["params"] = dict(request.url.params)
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0}, tmax={"20200101": 30.0}, tmin={"20200101": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36,
            longitude=90.35,
            start=date(2020, 1, 1),
            end=date(2020, 1, 1),
            parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        )
    finally:
        await client.aclose()

    assert captured["params"]["parameters"] == "PRECTOTCORR,T2M_MAX,T2M_MIN"


async def test_http_error_is_mapped_cleanly() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(503, text="upstream unavailable")

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerRequestError):
            await client.fetch_daily_point(
                latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()


async def test_malformed_response_is_rejected() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"unexpected": "shape"})

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerResponseError):
            await client.fetch_daily_point(
                latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()


async def test_non_json_response_is_rejected() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="not json at all")

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerResponseError):
            await client.fetch_daily_point(
                latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()


async def test_unexpected_time_standard_is_rejected() -> None:
    """We always request LST explicitly; an echoed mismatch means the
    response cannot be trusted to answer the question we asked."""

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0},
                tmax={"20200101": 30.0},
                tmin={"20200101": 20.0},
                time_standard="UTC",
            ),
        )

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerResponseError):
            await client.fetch_daily_point(
                latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()


async def test_missing_parameter_is_not_converted_to_zero() -> None:
    """A day absent from the fill-value-sentinel-normalized series (or a
    day matching the response's own declared fill value) must come back
    as None, never as a fabricated 0.0."""

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                # Day 2 missing entirely; day 3 uses the fill-value sentinel.
                precip={"20200101": 5.0, "20200103": FILL_VALUE},
                tmax={"20200101": 30.0, "20200103": 29.0},
                tmin={"20200101": 20.0, "20200103": 19.0},
            ),
        )

    client = _client_with_transport(handler)
    try:
        response = await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 3)
        )
    finally:
        await client.aclose()

    by_date = {record.date: record for record in response.records}
    assert by_date[date(2020, 1, 1)].precipitation_mm == 5.0
    assert by_date[date(2020, 1, 2)].precipitation_mm is None
    # Fill-value sentinel must be normalized to None, not left as -999.0.
    assert by_date[date(2020, 1, 3)].precipitation_mm is None


async def test_provenance_preserves_source_url() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0}, tmax={"20200101": 30.0}, tmin={"20200101": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        response = await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    finally:
        await client.aclose()

    assert response.provenance.source_url.startswith("https://power.larc.nasa.gov")
    assert DAILY_POINT_ENDPOINT in response.provenance.source_url
    assert response.provenance.data_mode == "live"
    assert response.provenance.provider == "NASA POWER"


async def test_no_auth_token_invented() -> None:
    """NASA POWER's Daily Point endpoint is unauthenticated; the client
    must never attach an Authorization header of its own invention."""
    captured: dict = {}

    def handler(request: httpx.Request) -> httpx.Response:
        captured["headers"] = dict(request.headers)
        return httpx.Response(
            200,
            json=_synthetic_power_payload(
                precip={"20200101": 1.0}, tmax={"20200101": 30.0}, tmin={"20200101": 20.0}
            ),
        )

    client = _client_with_transport(handler)
    try:
        await client.fetch_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    finally:
        await client.aclose()

    assert "authorization" not in captured["headers"]


async def test_invalid_latitude_rejected_before_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("must not reach the network for an invalid request")

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerValidationError):
            await client.fetch_daily_point(
                latitude=999.0, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()


async def test_invalid_date_range_rejected_before_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("must not reach the network for an invalid request")

    client = _client_with_transport(handler)
    try:
        with pytest.raises(NasaPowerValidationError):
            await client.fetch_daily_point(
                latitude=24.36, longitude=90.35, start=date(2020, 1, 10), end=date(2020, 1, 1)
            )
    finally:
        await client.aclose()
