"""Liveness endpoint: the app boots and serves without authentication."""

from httpx import AsyncClient


async def test_health_returns_ok(client: AsyncClient) -> None:
    response = await client.get("/api/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["environment"] == "test"
    assert body["version"]


async def test_health_requires_no_token(client: AsyncClient) -> None:
    """A probe has no Supabase token; the endpoint must not demand one."""
    response = await client.get("/api/v1/health")
    assert response.status_code == 200


async def test_protected_route_rejects_missing_token(client: AsyncClient) -> None:
    """Counterpart to the above: everything else is still guarded."""
    response = await client.get("/api/v1/identity/me")
    assert response.status_code == 401
