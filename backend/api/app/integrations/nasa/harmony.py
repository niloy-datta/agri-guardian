"""NASA Harmony: on-the-fly satellite subsetting.

Verified live (no token): `GET /capabilities?collectionid=<concept id>`
returns the service summary for a collection - e.g. for
`C2723754864-GES_DISC` (GPM_3IMERGDF) it reported bbox, temporal,
variable and shape subsetting, reprojection, and the output formats.

**Unverified against live data:** the OGC-API Coverages request below
(`/{collection}/ogc-api-coverages/1.0.0/collections/{variable}/coverage/rangeset`
with `subset=lat(..)`, `subset=lon(..)`, `subset=time("..":"..")`) follows
Harmony's documented interface but was not executed here because it
requires an Earthdata bearer token. It returns the raw bytes (NetCDF or
CSV, per `format`) and deliberately does not parse them - the same rule
the project applies to the IMERG client. Run `scripts/integration_smoke.py`
with a token to confirm it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import validate_bbox, validate_date_range
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "NASA Harmony"


@dataclass(frozen=True, slots=True)
class HarmonyCapabilities:
    concept_id: str
    short_name: str | None
    bbox_subsetting: bool
    temporal_subsetting: bool
    variable_subsetting: bool
    shape_subsetting: bool
    output_formats: list[str]
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class HarmonyCoverage:
    content: bytes
    content_type: str | None
    provenance: Provenance


class HarmonyClient:
    def __init__(self, *, base_url: str, token: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._token = token
        self._http = http

    async def get_capabilities(self, collection_concept_id: str) -> HarmonyCapabilities:
        result = await self._http.get(
            f"{self._base}/capabilities",
            dataset="Harmony capabilities",
            params={"collectionid": collection_concept_id},
        )
        body = result.json()
        try:
            summary = body["summary"]
            subsetting = summary["subsetting"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"capabilities response missing field: {exc}", provider=PROVIDER
            ) from exc
        return HarmonyCapabilities(
            concept_id=str(body.get("conceptId", collection_concept_id)),
            short_name=body.get("shortName"),
            bbox_subsetting=bool(subsetting.get("bbox")),
            temporal_subsetting=bool(subsetting.get("temporal")),
            variable_subsetting=bool(subsetting.get("variable")),
            shape_subsetting=bool(subsetting.get("shape")),
            output_formats=[str(f["name"]) for f in summary.get("outputFormats", []) if "name" in f],
            raw=body,
        )

    async def fetch_coverage_rangeset(
        self,
        *,
        collection_concept_id: str,
        variable: str,
        bbox: tuple[float, float, float, float],
        start: date,
        end: date,
        output_format: str = "text/csv",
    ) -> HarmonyCoverage:
        if not self._token:
            raise IntegrationCredentialsMissingError(
                "NASA Earthdata token is required for Harmony data requests", provider=PROVIDER
            )
        west, south, east, north = validate_bbox(*bbox, provider=PROVIDER)
        validate_date_range(start, end, provider=PROVIDER)
        if not variable:
            raise IntegrationValidationError("variable is required", provider=PROVIDER)
        url = (
            f"{self._base}/{collection_concept_id}/ogc-api-coverages/1.0.0/collections/"
            f"{variable}/coverage/rangeset"
        )
        # Harmony's subset syntax repeats the `subset` key, so pass a list
        # of tuples rather than a dict.
        params = [
            ("subset", f"lat({south}:{north})"),
            ("subset", f"lon({west}:{east})"),
            ("subset", f'time("{start.isoformat()}T00:00:00Z":"{end.isoformat()}T23:59:59Z")'),
            ("format", output_format),
        ]
        result = await self._http.get(
            url,
            dataset=f"Harmony {collection_concept_id}",
            params=params,
            bearer=self._token,
        )
        return HarmonyCoverage(
            content=result.content,
            content_type=result.response.headers.get("content-type"),
            provenance=result.provenance,
        )
