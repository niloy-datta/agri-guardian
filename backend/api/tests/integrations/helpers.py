"""Shared helpers for integration-client tests.

No test in the `test_integrations_*` files touches the network: every
request is served by `httpx.MockTransport`. Response bodies mirror the
shapes captured from the live services while the clients were written
(see each client's module docstring), but the *values* are SYNTHETIC TEST
DATA - not observations.
"""

from __future__ import annotations

from collections.abc import Callable

import httpx

from app.integrations.common.http import ProviderHttp

Handler = Callable[[httpx.Request], httpx.Response]


async def _no_sleep(_: float) -> None:
    return None


def make_http(
    handler: Handler,
    *,
    provider: str = "TestProvider",
    offline: bool = False,
    max_retries: int = 2,
    sleeps: list[float] | None = None,
) -> ProviderHttp:
    async def record_sleep(seconds: float) -> None:
        if sleeps is not None:
            sleeps.append(seconds)

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return ProviderHttp(
        provider=provider,
        http_client=client,
        offline=offline,
        max_retries=max_retries,
        sleep=record_sleep if sleeps is not None else _no_sleep,
    )


def json_response(body: object, status: int = 200) -> httpx.Response:
    return httpx.Response(status, json=body)
