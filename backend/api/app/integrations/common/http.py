"""Shared async HTTP layer for provider integrations.

One place for the cross-cutting behaviour every client needs, so the
per-provider modules only describe *what* to ask for:

- explicit offline mode (never inferred): zero network calls, clear error
- bounded retries with exponential backoff for transport errors, 429 and
  5xx (honouring `Retry-After`); 4xx other than 429 is never retried
- 401/403 -> `IntegrationAuthError`, so callers can distinguish "bad
  credentials" from "provider down"
- credentials are redacted from every URL that reaches an exception
  message or provenance record
- an injectable `sleep` so tests never really wait
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import httpx

from app.integrations.common.errors import (
    IntegrationAuthError,
    IntegrationOfflineError,
    IntegrationRequestError,
    IntegrationResponseError,
)

_SECRET_QUERY_KEYS = frozenset(
    {"api_key", "apikey", "key", "token", "access_token", "client_secret", "sig", "signature"}
)
_RETRYABLE_STATUS = frozenset({429, 500, 502, 503, 504})

TokenProvider = Callable[[], Awaitable[str]]
Sleep = Callable[[float], Awaitable[None]]


def redact_url(url: str) -> str:
    """Replaces the value of secret-looking query parameters with `***`."""
    parts = urlsplit(url)
    if not parts.query:
        return url
    pairs = [
        (k, "***" if k.lower() in _SECRET_QUERY_KEYS else v)
        for k, v in parse_qsl(parts.query, keep_blank_values=True)
    ]
    return urlunsplit(parts._replace(query=urlencode(pairs, safe="*")))


@dataclass(frozen=True, slots=True)
class Provenance:
    """Where a piece of evidence came from. `source_url` is redacted."""

    provider: str
    dataset: str
    source_url: str
    retrieved_at: datetime
    data_mode: str = "live"
    notes: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class HttpResult:
    """A successful response plus the redacted URL that produced it."""

    response: httpx.Response
    provenance: Provenance

    def json(self) -> Any:
        try:
            return self.response.json()
        except ValueError as exc:
            raise IntegrationResponseError(
                f"{self.provenance.provider} response was not valid JSON",
                provider=self.provenance.provider,
            ) from exc

    @property
    def content(self) -> bytes:
        return self.response.content

    @property
    def text(self) -> str:
        return self.response.text


class ProviderHttp:
    """Retrying, redacting wrapper around one `httpx.AsyncClient`."""

    def __init__(
        self,
        *,
        provider: str,
        timeout_seconds: float = 30.0,
        max_retries: int = 2,
        offline: bool = False,
        http_client: httpx.AsyncClient | None = None,
        sleep: Sleep = asyncio.sleep,
        backoff_base_seconds: float = 0.5,
    ) -> None:
        self.provider = provider
        self._timeout = timeout_seconds
        self._max_retries = max_retries
        self._offline = offline
        self._owns_client = http_client is None
        self._client = http_client or httpx.AsyncClient()
        self._sleep = sleep
        self._backoff_base = backoff_base_seconds

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def __aenter__(self) -> ProviderHttp:
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self.aclose()

    async def request(
        self,
        method: str,
        url: str,
        *,
        dataset: str,
        params: Mapping[str, Any] | None = None,
        json_body: Any = None,
        data: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
        bearer: str | None = None,
        basic_auth: tuple[str, str] | None = None,
        follow_redirects: bool = True,
    ) -> HttpResult:
        if self._offline:
            raise IntegrationOfflineError(
                f"{self.provider}: offline mode is on, refusing to call {redact_url(url)}",
                provider=self.provider,
            )

        request_headers = dict(headers or {})
        if bearer:
            request_headers["Authorization"] = f"Bearer {bearer}"
        auth = httpx.BasicAuth(*basic_auth) if basic_auth else None

        last_error: str = ""
        for attempt in range(self._max_retries + 1):
            try:
                response = await self._client.request(
                    method,
                    url,
                    params=params,
                    json=json_body,
                    data=data,
                    headers=request_headers,
                    auth=auth,
                    timeout=self._timeout,
                    follow_redirects=follow_redirects,
                )
            except httpx.HTTPError as exc:
                last_error = f"transport error: {type(exc).__name__}: {exc}"
                if attempt < self._max_retries:
                    await self._sleep(self._backoff_base * (2**attempt))
                    continue
                raise IntegrationRequestError(
                    f"{self.provider} request failed after {attempt + 1} attempt(s): "
                    f"{last_error} ({redact_url(url)})",
                    provider=self.provider,
                ) from exc

            safe_url = redact_url(str(response.request.url))
            status = response.status_code

            if status in (401, 403):
                raise IntegrationAuthError(
                    f"{self.provider} rejected the credentials (HTTP {status}) for {safe_url}: "
                    f"{response.text[:300]}",
                    provider=self.provider,
                )
            if status in _RETRYABLE_STATUS and attempt < self._max_retries:
                await self._sleep(self._retry_delay(response, attempt))
                continue
            if status >= 400:
                raise IntegrationRequestError(
                    f"{self.provider} returned HTTP {status} for {safe_url}: "
                    f"{response.text[:500]}",
                    provider=self.provider,
                    status_code=status,
                )

            return HttpResult(
                response=response,
                provenance=Provenance(
                    provider=self.provider,
                    dataset=dataset,
                    source_url=safe_url,
                    retrieved_at=datetime.now(UTC),
                ),
            )

        raise IntegrationRequestError(  # pragma: no cover - loop always returns/raises
            f"{self.provider} request failed: {last_error}", provider=self.provider
        )

    def _retry_delay(self, response: httpx.Response, attempt: int) -> float:
        retry_after = response.headers.get("Retry-After")
        if retry_after:
            try:
                return min(float(retry_after), 30.0)
            except ValueError:
                pass
        return self._backoff_base * (2**attempt)

    async def get(self, url: str, *, dataset: str, **kwargs: Any) -> HttpResult:
        return await self.request("GET", url, dataset=dataset, **kwargs)

    async def post(self, url: str, *, dataset: str, **kwargs: Any) -> HttpResult:
        return await self.request("POST", url, dataset=dataset, **kwargs)
