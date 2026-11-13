"""Tests for the Phase 4B.1 GPM IMERG acquisition-layer scaffold
(`app/integrations/nasa/imerg_client.py`). This module has never
acquired real IMERG data (no NASA Earthdata credentials exist in this
environment - see `docs/references/gpm_imerg_cross_validation.md`), so
these tests cover exactly what is actually implemented: coordinate ->
grid-cell resolution, URL construction, and the authentication-gating
behavior - each verified against real, live (but unauthenticated) GES
DISC responses captured during this phase's research, not invented
values. No test here claims to exercise a real authenticated data
fetch.
"""

from __future__ import annotations

from datetime import date

import httpx
import pytest

from app.integrations.nasa.imerg_client import (
    GpmImergAuthenticationError,
    GpmImergClient,
    GpmImergCredentialsMissingError,
    GpmImergValidationError,
    build_daily_granule_filename,
    build_daily_granule_opendap_url,
    build_daily_point_ascii_request_url,
    resolve_grid_cell,
)


class TestResolveGridCell:
    def test_rajshahi_pilot_coordinate_matches_live_verified_grid_indices(self) -> None:
        """These exact index values (2686, 1144) and the resulting grid
        cell center (88.6, 24.4) were confirmed by actually querying the
        real GES DISC OPeNDAP server for the Rajshahi pilot coordinate
        (24.37400, 88.60114) during this phase's research - not derived
        purely from the formula in isolation."""
        cell = resolve_grid_cell(latitude=24.37400, longitude=88.60114)
        assert cell.longitude_index == 2686
        assert cell.latitude_index == 1144
        assert cell.grid_cell_longitude == pytest.approx(88.6, abs=1e-9)
        assert cell.grid_cell_latitude == pytest.approx(24.4, abs=1e-9)
        assert cell.requested_latitude == 24.37400
        assert cell.requested_longitude == 88.60114

    def test_grid_cell_is_never_reported_as_identical_to_requested_coordinate(self) -> None:
        cell = resolve_grid_cell(latitude=24.37400, longitude=88.60114)
        assert cell.spatial_offset_km > 0.0
        assert cell.grid_cell_latitude != cell.requested_latitude
        assert cell.grid_cell_longitude != cell.requested_longitude

    def test_exact_grid_center_coordinate_has_zero_offset(self) -> None:
        cell = resolve_grid_cell(latitude=24.4, longitude=88.6)
        assert cell.spatial_offset_km == pytest.approx(0.0, abs=1e-6)

    def test_out_of_range_latitude_rejected(self) -> None:
        with pytest.raises(GpmImergValidationError):
            resolve_grid_cell(latitude=91.0, longitude=0.0)

    def test_out_of_range_longitude_rejected(self) -> None:
        with pytest.raises(GpmImergValidationError):
            resolve_grid_cell(latitude=0.0, longitude=181.0)


class TestGranuleUrlConstruction:
    def test_filename_matches_live_verified_real_pattern(self) -> None:
        """Confirmed against a real, live, unauthenticated GES DISC
        directory listing for GPM_3IMERGDF.07/2020/01/ during this
        phase's research."""
        filename = build_daily_granule_filename(date(2020, 1, 1))
        assert filename == "3B-DAY.MS.MRG.3IMERG.20200101-S000000-E235959.V07B.nc4"

    def test_opendap_url_matches_live_verified_real_path(self) -> None:
        url = build_daily_granule_opendap_url(
            base_url="https://gpm1.gesdisc.eosdis.nasa.gov", day=date(2020, 1, 1)
        )
        assert url == (
            "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDF.07/"
            "2020/01/3B-DAY.MS.MRG.3IMERG.20200101-S000000-E235959.V07B.nc4"
        )

    def test_ascii_request_url_uses_resolved_grid_indices(self) -> None:
        cell = resolve_grid_cell(latitude=24.37400, longitude=88.60114)
        url = build_daily_point_ascii_request_url(
            base_url="https://gpm1.gesdisc.eosdis.nasa.gov", day=date(2020, 1, 1), grid_cell=cell
        )
        assert url.endswith(".ascii?precipitation[0][2686][1144]")


def _capture_transport(captured: dict[str, httpx.Request]) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        captured["request"] = request
        return httpx.Response(200, text="dummy body - never parsed by this client")

    return httpx.MockTransport(handler)


def _fail_transport(request: httpx.Request) -> httpx.Response:
    raise AssertionError(f"Network call attempted without a token: {request.url}")


class TestFetchDailyPrecipitationRawAuthGating:
    async def test_missing_token_raises_before_any_network_call(self) -> None:
        client = GpmImergClient(
            earthdata_token="",
            http_client=httpx.AsyncClient(transport=httpx.MockTransport(_fail_transport)),
        )
        with pytest.raises(GpmImergCredentialsMissingError):
            await client.fetch_daily_precipitation_raw(
                latitude=24.37400, longitude=88.60114, day=date(2020, 1, 1)
            )
        await client.aclose()

    async def test_configured_token_is_sent_as_bearer_header(self) -> None:
        captured: dict[str, httpx.Request] = {}
        client = GpmImergClient(
            earthdata_token="test-token-value",
            http_client=httpx.AsyncClient(transport=_capture_transport(captured)),
        )
        response = await client.fetch_daily_precipitation_raw(
            latitude=24.37400, longitude=88.60114, day=date(2020, 1, 1)
        )
        await client.aclose()

        assert response.status_code == 200
        sent_request = captured["request"]
        assert sent_request.headers["authorization"] == "Bearer test-token-value"
        assert "precipitation[0][2686][1144]" in str(sent_request.url)

    async def test_401_response_raises_clear_authentication_error_not_generic_failure(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(401, text="HTTP Basic: Access denied.")

        client = GpmImergClient(
            earthdata_token="expired-or-unauthorized-token",
            http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
        )
        with pytest.raises(GpmImergAuthenticationError):
            await client.fetch_daily_precipitation_raw(
                latitude=24.37400, longitude=88.60114, day=date(2020, 1, 1)
            )
        await client.aclose()

    async def test_earthdata_oauth_redirect_is_never_silently_followed(self) -> None:
        """Reproduces the exact live behavior confirmed in this phase's
        research: a real data-slice request without valid auth returns a
        302 to urs.earthdata.nasa.gov, not a 401. This must be treated as
        an authentication failure, never as if the redirect target were
        the actual data."""

        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(
                302,
                headers={
                    "location": (
                        "https://urs.earthdata.nasa.gov/oauth/authorize/"
                        "?scope=uid&client_id=e2WVk8Pw6weeLUKZYOxvTQ"
                    )
                },
            )

        client = GpmImergClient(
            earthdata_token="token-not-accepted-by-this-resource",
            http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
        )
        with pytest.raises(GpmImergAuthenticationError):
            await client.fetch_daily_precipitation_raw(
                latitude=24.37400, longitude=88.60114, day=date(2020, 1, 1)
            )
        await client.aclose()

    async def test_invalid_coordinates_rejected_before_any_network_call(self) -> None:
        client = GpmImergClient(
            earthdata_token="irrelevant-because-should-never-be-used",
            http_client=httpx.AsyncClient(transport=httpx.MockTransport(_fail_transport)),
        )
        with pytest.raises(GpmImergValidationError):
            await client.fetch_daily_precipitation_raw(
                latitude=999.0, longitude=88.60114, day=date(2020, 1, 1)
            )
        await client.aclose()
