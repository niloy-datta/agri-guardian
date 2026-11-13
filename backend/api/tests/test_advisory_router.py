"""Router-level tests for POST /api/v1/advisory/planting-window.

Uses the real FastAPI app and the real auth dependency chain (so 401
handling is genuinely exercised against PostgreSQL/Redis, per this
project's existing test convention - see `tests/conftest.py`), but with
`get_advisory_service` overridden to a fake NASA-POWER-backed service so
no live NASA network call ever happens here.
"""

from collections.abc import AsyncIterator
from datetime import UTC, date, datetime, timedelta

import pytest
from httpx import ASGITransport, AsyncClient

from app.integrations.nasa.client import NasaPowerProvenance, PowerDailyRecord, PowerDailyResponse
from app.integrations.nasa.power_cache import CacheLookupResult
from app.main import create_app
from app.modules.advisory.router import get_advisory_service
from app.modules.advisory.service import AdvisoryService
from tests.conftest import auth_headers


class _FakeCache:
    def __init__(self, response: PowerDailyResponse) -> None:
        self._response = response

    async def get_daily_point(self, **_kwargs: object) -> CacheLookupResult:
        return CacheLookupResult(response=self._response, source="fixture")


def _synthetic_response(onset_month_day_by_year: dict[int, tuple[int, int]]) -> PowerDailyResponse:
    """SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS."""
    start, end = date(2001, 1, 1), date(2015, 12, 31)
    records: list[PowerDailyRecord] = []
    day = start
    while day <= end:
        onset = onset_month_day_by_year.get(day.year)
        precip = 6.0 if onset is not None and day >= date(day.year, *onset) else 0.0
        records.append(PowerDailyRecord(date=day, precipitation_mm=precip, tmax_c=30.0, tmin_c=20.0))
        day += timedelta(days=1)

    provenance = NasaPowerProvenance(
        provider="NASA POWER",
        dataset_id="SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS",
        source_url="file://synthetic-test-fixture",
        endpoint="/api/temporal/daily/point",
        community="AG",
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        latitude=24.36,
        longitude=90.35,
        start_date=start,
        end_date=end,
        time_standard="LST",
        retrieved_at=datetime(2020, 1, 1, tzinfo=UTC),
        units={"PRECTOTCORR": "mm/day", "T2M_MAX": "C", "T2M_MIN": "C"},
        raw_metadata={},
        data_mode="fixture",
    )
    return PowerDailyResponse(records=records, provenance=provenance, raw={})


REFERENCE_ONSETS = {2001: (4, 1), 2002: (4, 3), 2003: (3, 30)}
RECENT_ONSETS = {2013: (5, 1), 2014: (5, 4), 2015: (4, 29)}
"""Deliberately non-identical within each period - a Mann-Whitney test on
perfectly tied samples degenerates to a non-finite statistic, which
`mann_whitney_shift_test` correctly reports as 'degenerate_data' rather
than a fabricated number that JSON would silently render as null."""


def _valid_payload(**overrides: object) -> dict:
    payload = {
        "latitude": 24.36,
        "longitude": 90.35,
        "start_year": 2001,
        "end_year": 2015,
        "reference_start_year": 2001,
        "reference_end_year": 2003,
        "recent_start_year": 2013,
        "recent_end_year": 2015,
        "base_temperature_c": 10.0,
    }
    payload.update(overrides)
    return payload


@pytest.fixture
async def advisory_client(resources: None) -> AsyncIterator[AsyncClient]:
    """A dedicated app instance (not the shared `client` fixture) so
    `get_advisory_service` can be overridden without affecting any other
    test's app."""
    app = create_app()
    fake_service = AdvisoryService(
        cache=_FakeCache(
            _synthetic_response({**REFERENCE_ONSETS, **RECENT_ONSETS})
        )
    )
    app.dependency_overrides[get_advisory_service] = lambda: fake_service
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as http:
        yield http
    app.dependency_overrides.clear()


async def test_unauthenticated_call_returns_401(advisory_client: AsyncClient) -> None:
    response = await advisory_client.post(
        "/api/v1/advisory/planting-window", json=_valid_payload()
    )
    assert response.status_code == 401


async def test_authenticated_request_returns_structured_response(
    advisory_client: AsyncClient,
) -> None:
    response = await advisory_client.post(
        "/api/v1/advisory/planting-window",
        json=_valid_payload(),
        headers=auth_headers("advisory-farmer"),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["data_status"] == "ok"
    assert body["shift_days"] is not None
    assert body["provenance"]["provider"] == "NASA POWER"
    assert len(body["assumptions"]) >= 3
    assert len(body["sensitivity"]) == 3
    assert body["mann_whitney_u"] is not None
    assert body["p_value"] is not None


async def test_invalid_latitude_returns_422(advisory_client: AsyncClient) -> None:
    response = await advisory_client.post(
        "/api/v1/advisory/planting-window",
        json=_valid_payload(latitude=999.0),
        headers=auth_headers("advisory-farmer"),
    )
    assert response.status_code == 422


async def test_invalid_longitude_returns_422(advisory_client: AsyncClient) -> None:
    response = await advisory_client.post(
        "/api/v1/advisory/planting-window",
        json=_valid_payload(longitude=-999.0),
        headers=auth_headers("advisory-farmer"),
    )
    assert response.status_code == 422


async def test_invalid_period_ordering_returns_422(advisory_client: AsyncClient) -> None:
    response = await advisory_client.post(
        "/api/v1/advisory/planting-window",
        json=_valid_payload(reference_start_year=2012, reference_end_year=2001),
        headers=auth_headers("advisory-farmer"),
    )
    assert response.status_code == 422


async def test_missing_base_temperature_returns_422(advisory_client: AsyncClient) -> None:
    payload = _valid_payload()
    del payload["base_temperature_c"]

    response = await advisory_client.post(
        "/api/v1/advisory/planting-window",
        json=payload,
        headers=auth_headers("advisory-farmer"),
    )
    assert response.status_code == 422


async def test_insufficient_data_produces_honest_status_via_http(
    resources: None,
) -> None:
    app = create_app()
    fake_service = AdvisoryService(
        cache=_FakeCache(_synthetic_response({2001: (4, 1)}))  # only one qualifying year
    )
    app.dependency_overrides[get_advisory_service] = lambda: fake_service
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as http:
        response = await http.post(
            "/api/v1/advisory/planting-window",
            json=_valid_payload(),
            headers=auth_headers("advisory-farmer-2"),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["data_status"] != "ok"
    assert body["shift_days"] is None
