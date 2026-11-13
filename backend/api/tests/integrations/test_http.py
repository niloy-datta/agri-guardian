"""ProviderHttp: retries, offline mode, auth errors, secret redaction, OAuth cache."""

import httpx
import pytest

from app.integrations.common.errors import (
    IntegrationAuthError,
    IntegrationCredentialsMissingError,
    IntegrationOfflineError,
    IntegrationRequestError,
    IntegrationResponseError,
)
from app.integrations.common.geo import (
    polygon_bbox,
    validate_bbox,
    validate_polygon_geojson,
)
from app.integrations.common.http import redact_url
from app.integrations.common.oauth import ClientCredentialsTokenSource
from tests.integrations.helpers import json_response, make_http

SQUARE = {
    "type": "Polygon",
    "coordinates": [[[88.0, 24.0], [88.1, 24.0], [88.1, 24.1], [88.0, 24.1], [88.0, 24.0]]],
}


def test_redact_url_hides_secret_query_values_only() -> None:
    url = "https://x.test/api?API_Key=abc123&south=24.3&token=zzz"
    redacted = redact_url(url)
    assert "abc123" not in redacted and "zzz" not in redacted
    assert "south=24.3" in redacted


async def test_retries_5xx_then_succeeds_with_backoff() -> None:
    calls = {"n": 0}
    sleeps: list[float] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(503) if calls["n"] < 3 else json_response({"ok": True})

    http = make_http(handler, sleeps=sleeps)
    result = await http.get("https://x.test/a", dataset="d")
    assert result.json() == {"ok": True}
    assert calls["n"] == 3
    assert sleeps == [0.5, 1.0]


async def test_honours_retry_after_on_429() -> None:
    calls = {"n": 0}
    sleeps: list[float] = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        if calls["n"] == 1:
            return httpx.Response(429, headers={"Retry-After": "7"})
        return json_response({})

    await make_http(handler, sleeps=sleeps).get("https://x.test/a", dataset="d")
    assert sleeps == [7.0]


async def test_does_not_retry_plain_4xx_and_error_has_status_and_redacted_url() -> None:
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(404, text="nope")

    http = make_http(handler)
    with pytest.raises(IntegrationRequestError) as exc:
        await http.get("https://x.test/a", dataset="d", params={"API_Key": "SECRET"})
    assert calls["n"] == 1
    assert exc.value.status_code == 404
    assert "SECRET" not in str(exc.value)


async def test_exhausted_retries_raise_request_error() -> None:
    http = make_http(lambda r: httpx.Response(500), max_retries=1)
    with pytest.raises(IntegrationRequestError):
        await http.get("https://x.test/a", dataset="d")


async def test_transport_error_is_retried_then_raised() -> None:
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        raise httpx.ConnectError("boom")

    with pytest.raises(IntegrationRequestError, match="transport error"):
        await make_http(handler, max_retries=2).get("https://x.test/a", dataset="d")
    assert calls["n"] == 3


@pytest.mark.parametrize("status", [401, 403])
async def test_auth_failures_map_to_auth_error_without_retry(status: int) -> None:
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        return httpx.Response(status, text="denied")

    with pytest.raises(IntegrationAuthError):
        await make_http(handler).get("https://x.test/a", dataset="d")
    assert calls["n"] == 1


async def test_offline_mode_makes_no_network_call() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("network must not be touched")

    with pytest.raises(IntegrationOfflineError):
        await make_http(handler, offline=True).get("https://x.test/a", dataset="d")


async def test_invalid_json_raises_response_error() -> None:
    http = make_http(lambda r: httpx.Response(200, text="<html>"))
    result = await http.get("https://x.test/a", dataset="d")
    with pytest.raises(IntegrationResponseError):
        result.json()


def test_bbox_and_polygon_validation() -> None:
    assert validate_bbox(88.0, 24.0, 89.0, 25.0) == (88.0, 24.0, 89.0, 25.0)
    for bad in [(89.0, 24.0, 88.0, 25.0), (88.0, 25.0, 89.0, 24.0), (88.0, 24.0, 189.0, 25.0)]:
        with pytest.raises(Exception, match="bbox|longitude|latitude"):
            validate_bbox(*bad)
    assert validate_polygon_geojson(SQUARE) is SQUARE
    assert polygon_bbox(SQUARE) == (88.0, 24.0, 88.1, 24.1)
    open_ring = {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1]]]}
    with pytest.raises(Exception, match="not closed"):
        validate_polygon_geojson(open_ring)
    with pytest.raises(Exception, match="Polygon"):
        validate_polygon_geojson({"type": "Point", "coordinates": [0, 0]})


async def test_oauth_token_is_cached_until_expiry() -> None:
    calls = {"n": 0}
    now = {"t": 0.0}

    def handler(request: httpx.Request) -> httpx.Response:
        calls["n"] += 1
        assert b"grant_type=client_credentials" in request.content
        return json_response({"access_token": f"tok{calls['n']}", "expires_in": 300})

    source = ClientCredentialsTokenSource(
        http=make_http(handler),
        token_url="https://auth.test/token",
        client_id="id",
        client_secret="secret",
        clock=lambda: now["t"],
    )
    assert await source.get_token() == "tok1"
    assert await source.get_token() == "tok1"
    assert calls["n"] == 1
    now["t"] = 400.0
    assert await source.get_token() == "tok2"


async def test_oauth_without_credentials_fails_before_network() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise AssertionError("must not call network")

    source = ClientCredentialsTokenSource(
        http=make_http(handler), token_url="https://auth.test/token", client_id="", client_secret=""
    )
    with pytest.raises(IntegrationCredentialsMissingError):
        await source.get_token()
