"""Readiness probe: real PostgreSQL and Redis round-trips.

The negative test matters more than the positive one. An endpoint that
returns `ready: true` unconditionally passes the happy-path test just as
well as a correct one, so the suite also asserts that an app with no
database and no Redis reports 503.
"""

from httpx import AsyncClient


async def test_ready_reports_live_dependencies(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health/ready")

    assert response.status_code == 200
    body = response.json()
    assert body["ready"] is True

    by_name = {dep["name"]: dep for dep in body["dependencies"]}
    assert by_name["postgresql"]["healthy"] is True
    assert by_name["redis"]["healthy"] is True


async def test_ready_reports_both_dependencies(client: AsyncClient) -> None:
    body = (await client.get("/api/v1/health/ready")).json()
    assert {dep["name"] for dep in body["dependencies"]} == {"postgresql", "redis"}


async def test_ready_fails_when_dependencies_are_absent(
    offline_client: AsyncClient,
) -> None:
    response = await offline_client.get("/api/v1/health/ready")

    assert response.status_code == 503
    body = response.json()
    assert body["ready"] is False
    assert all(dep["healthy"] is False for dep in body["dependencies"])
    assert all(dep["detail"] for dep in body["dependencies"])
