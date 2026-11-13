"""Google Earth Engine REST API (earthengine.googleapis.com/v1).

**Unverified against a live project.** Earth Engine needs a Google Cloud
project with the Earth Engine API enabled, a registered service account and
its key, none of which exist for this project yet. This client is therefore
deliberately thin and honest:

- authentication: `ServiceAccountTokenSource` uses `google-auth` when it is
  installed (it is NOT a dependency of this project) and raises a clear
  `IntegrationCredentialsMissingError` otherwise;
- `compute_value` posts an Earth Engine *expression graph* to
  `projects/{project}/value:compute` and returns the decoded `result`. The
  caller supplies the expression; this module does not invent EE
  expressions it cannot test;
- `get_asset` reads asset metadata from `projects/{project}/assets/{id}`.

Use this when Sentinel Hub / AppEEARS cannot express the analysis. Run
`scripts/integration_smoke.py` with GEE configured to confirm it.
"""

from __future__ import annotations

import asyncio
from typing import Any

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.http import ProviderHttp

PROVIDER = "Google Earth Engine"
_SCOPES = ("https://www.googleapis.com/auth/earthengine.readonly",)


class ServiceAccountTokenSource:
    def __init__(self, *, key_file: str) -> None:
        self._key_file = key_file
        self._credentials: Any = None

    async def get_token(self) -> str:
        if not self._key_file:
            raise IntegrationCredentialsMissingError(
                "gee_service_account_file is not configured", provider=PROVIDER
            )
        try:
            from google.auth.transport.requests import Request
            from google.oauth2 import service_account
        except ImportError as exc:
            raise IntegrationCredentialsMissingError(
                "the optional `google-auth` package is required for Earth Engine "
                "service-account auth (pip install google-auth requests)",
                provider=PROVIDER,
            ) from exc
        if self._credentials is None:
            self._credentials = service_account.Credentials.from_service_account_file(
                self._key_file, scopes=list(_SCOPES)
            )
        credentials = self._credentials
        if not credentials.valid:
            # google-auth refresh is blocking I/O.
            await asyncio.to_thread(credentials.refresh, Request())
        return str(credentials.token)


class EarthEngineClient:
    def __init__(
        self,
        *,
        base_url: str,
        project: str,
        token_source: ServiceAccountTokenSource | None,
        http: ProviderHttp,
    ) -> None:
        self._base = base_url.rstrip("/")
        self._project = project
        self._tokens = token_source
        self._http = http

    async def compute_value(self, expression: dict[str, Any]) -> Any:
        if not expression:
            raise IntegrationValidationError("expression is empty", provider=PROVIDER)
        result = await self._http.post(
            f"{self._base}/projects/{self._require_project()}/value:compute",
            dataset="Earth Engine value:compute",
            json_body={"expression": expression},
            bearer=await self._token(),
        )
        body = result.json()
        if not isinstance(body, dict) or "result" not in body:
            raise IntegrationResponseError("response has no `result`", provider=PROVIDER)
        return body["result"]

    async def get_asset(self, asset_id: str) -> dict[str, Any]:
        if not asset_id or ".." in asset_id:
            raise IntegrationValidationError("invalid asset id", provider=PROVIDER)
        result = await self._http.get(
            f"{self._base}/projects/{self._require_project()}/assets/{asset_id}",
            dataset="Earth Engine asset",
            bearer=await self._token(),
        )
        body = result.json()
        if not isinstance(body, dict):
            raise IntegrationResponseError("asset response was not an object", provider=PROVIDER)
        return body

    def _require_project(self) -> str:
        if not self._project:
            raise IntegrationCredentialsMissingError(
                "gee_project is not configured", provider=PROVIDER
            )
        return self._project

    async def _token(self) -> str:
        if self._tokens is None:
            raise IntegrationCredentialsMissingError(
                "Earth Engine credentials are not configured", provider=PROVIDER
            )
        return await self._tokens.get_token()
