"""OAuth2 client-credentials token source with in-memory caching.

Used for Copernicus Data Space (Sentinel Hub, openEO). The token endpoint
and client id/secret come from settings; nothing is read from source.
"""

from __future__ import annotations

import time
from collections.abc import Callable

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
)
from app.integrations.common.http import ProviderHttp

_EXPIRY_SKEW_SECONDS = 30.0


class ClientCredentialsTokenSource:
    def __init__(
        self,
        *,
        http: ProviderHttp,
        token_url: str,
        client_id: str,
        client_secret: str,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._http = http
        self._token_url = token_url
        self._client_id = client_id
        self._client_secret = client_secret
        self._clock = clock
        self._token: str | None = None
        self._expires_at: float = 0.0

    async def get_token(self) -> str:
        if not self._client_id or not self._client_secret:
            raise IntegrationCredentialsMissingError(
                "OAuth client id/secret are not configured", provider=self._http.provider
            )
        if self._token and self._clock() < self._expires_at:
            return self._token

        result = await self._http.post(
            self._token_url,
            dataset="oauth-token",
            data={
                "grant_type": "client_credentials",
                "client_id": self._client_id,
                "client_secret": self._client_secret,
            },
        )
        body = result.json()
        token = body.get("access_token") if isinstance(body, dict) else None
        if not token:
            raise IntegrationResponseError(
                "token endpoint response had no access_token", provider=self._http.provider
            )
        expires_in = float(body.get("expires_in", 300))
        self._token = str(token)
        self._expires_at = self._clock() + max(expires_in - _EXPIRY_SKEW_SECONDS, 0.0)
        return self._token
