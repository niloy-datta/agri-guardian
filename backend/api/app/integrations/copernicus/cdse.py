"""Copernicus Data Space Ecosystem (CDSE): OData catalogue, openEO and S3.

Verified live (no credentials):
- OData `Products` search with `Collection/Name`, `contains(Name, ..)`,
  `OData.CSC.Intersects(area=geography'SRID=4326;POINT(lon lat)')`,
  `ContentDate/Start` and the `cloudCover` DoubleAttribute filter returned
  Sentinel-2 L2A products with `Id`, `Name`, `ContentLength`, `Online`,
  `S3Path` (e.g. `/eodata/Sentinel-2/MSI/L2A/2026/11/09/..SAFE`).
- openEO `GET /collections` and `/collections/SENTINEL2_L2A` (bands B01-B12...).
- Product download without a token returns HTTP 401, so downloading needs
  the OAuth token from `ClientCredentialsTokenSource`.

**Unverified against a live account:** the authenticated pieces - the
bearer-token product download URL and openEO's synchronous `POST /result`
(process graph in, raster bytes out). They follow CDSE's documented
interface; confirm with `scripts/integration_smoke.py` once
`copernicus_client_id/secret` are set.

**S3 (#20):** CDSE exposes the same archive over an S3 API at
`eodata.dataspace.copernicus.eu` (bucket `eodata`). Reading it needs S3
access keys generated in the CDSE console and an S3 SDK (boto3), which is
not a dependency of this project. `CdseS3Locator` therefore only resolves
an OData `S3Path` into the bucket/key/endpoint an S3 client needs - it
does not download.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from app.integrations.common.errors import (
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import validate_lat_lon
from app.integrations.common.http import Provenance, ProviderHttp
from app.integrations.common.oauth import ClientCredentialsTokenSource

PROVIDER = "Copernicus CDSE"
_COLLECTIONS = frozenset({"SENTINEL-1", "SENTINEL-2", "SENTINEL-3", "SENTINEL-5P"})


@dataclass(frozen=True, slots=True)
class CdseProduct:
    id: str
    name: str
    content_length: int | None
    online: bool
    s3_path: str | None
    content_start: datetime | None
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class S3Location:
    endpoint: str
    bucket: str
    key: str


class CdseS3Locator:
    def __init__(self, *, endpoint_url: str, bucket: str = "eodata") -> None:
        self._endpoint = endpoint_url.rstrip("/")
        self._bucket = bucket

    def locate(self, s3_path: str) -> S3Location:
        """`/eodata/Sentinel-2/...SAFE` -> bucket `eodata`, key `Sentinel-2/...SAFE`."""
        prefix = f"/{self._bucket}/"
        if not s3_path.startswith(prefix):
            raise IntegrationValidationError(
                f"S3Path {s3_path!r} does not start with {prefix!r}", provider=PROVIDER
            )
        return S3Location(
            endpoint=self._endpoint, bucket=self._bucket, key=s3_path[len(prefix) :]
        )


class CdseClient:
    def __init__(
        self,
        *,
        odata_url: str,
        download_url: str,
        openeo_url: str,
        http: ProviderHttp,
        token_source: ClientCredentialsTokenSource | None = None,
    ) -> None:
        self._odata = odata_url.rstrip("/")
        self._download = download_url.rstrip("/")
        self._openeo = openeo_url.rstrip("/")
        self._http = http
        self._tokens = token_source

    async def search_products(
        self,
        *,
        collection: str,
        latitude: float,
        longitude: float,
        start: datetime,
        name_contains: str | None = "MSIL2A",
        max_cloud_cover: float | None = None,
        top: int = 10,
    ) -> tuple[list[CdseProduct], Provenance]:
        """Newest-first products intersecting a point since `start`.
        `name_contains` defaults to Sentinel-2 L2A; pass None for no filter."""
        if collection not in _COLLECTIONS:
            raise IntegrationValidationError(
                f"collection must be one of {sorted(_COLLECTIONS)}", provider=PROVIDER
            )
        validate_lat_lon(latitude, longitude, provider=PROVIDER)
        if not 1 <= top <= 1000:
            raise IntegrationValidationError("top must be 1-1000", provider=PROVIDER)

        clauses = [
            f"Collection/Name eq '{collection}'",
            f"OData.CSC.Intersects(area=geography'SRID=4326;POINT({longitude} {latitude})')",
            f"ContentDate/Start gt {start.strftime('%Y-%m-%dT%H:%M:%S.000Z')}",
        ]
        if name_contains:
            if "'" in name_contains:
                raise IntegrationValidationError("invalid name filter", provider=PROVIDER)
            clauses.append(f"contains(Name,'{name_contains}')")
        if max_cloud_cover is not None:
            clauses.append(
                "Attributes/OData.CSC.DoubleAttribute/any(att:att/Name eq 'cloudCover' "
                f"and att/OData.CSC.DoubleAttribute/Value lt {max_cloud_cover:.2f})"
            )
        result = await self._http.get(
            f"{self._odata}/Products",
            dataset=f"CDSE {collection}",
            params={
                "$filter": " and ".join(clauses),
                "$orderby": "ContentDate/Start desc",
                "$top": top,
            },
        )
        body = result.json()
        rows = body.get("value") if isinstance(body, dict) else None
        if not isinstance(rows, list):
            raise IntegrationResponseError("OData response has no value array", provider=PROVIDER)
        return [self._parse(r) for r in rows], result.provenance

    def download_url(self, product_id: str) -> str:
        """URL of the product archive. Requires a bearer token to fetch."""
        return f"{self._download}/Products({product_id})/$value"

    async def download_product(self, product_id: str) -> bytes:
        """Downloads a whole product (often ~1 GB for Sentinel-2). Prefer
        `SentinelHubClient` for field-sized data."""
        token = await self._token()
        result = await self._http.get(
            self.download_url(product_id), dataset="CDSE download", bearer=token
        )
        return result.content

    async def list_openeo_collections(self) -> list[str]:
        result = await self._http.get(
            f"{self._openeo}/collections", dataset="openEO collections", params={"limit": 100}
        )
        body = result.json()
        try:
            return [str(c["id"]) for c in body["collections"]]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"openEO collections response malformed: {exc}", provider=PROVIDER
            ) from exc

    async def run_openeo_process_graph(self, process_graph: dict[str, Any]) -> bytes:
        """Synchronous openEO job: `POST /result` with a process graph.
        Keep the area small - long jobs must use batch jobs instead."""
        if not process_graph:
            raise IntegrationValidationError("process_graph is empty", provider=PROVIDER)
        result = await self._http.post(
            f"{self._openeo}/result",
            dataset="openEO result",
            json_body={"process": {"process_graph": process_graph}},
            bearer=await self._token(),
        )
        return result.content

    async def _token(self) -> str:
        if self._tokens is None:
            from app.integrations.common.errors import IntegrationCredentialsMissingError

            raise IntegrationCredentialsMissingError(
                "CDSE OAuth client is not configured", provider=PROVIDER
            )
        return await self._tokens.get_token()

    @staticmethod
    def _parse(row: dict[str, Any]) -> CdseProduct:
        content_date = row.get("ContentDate") or {}
        start = content_date.get("Start")
        return CdseProduct(
            id=str(row["Id"]),
            name=str(row.get("Name", "")),
            content_length=row.get("ContentLength"),
            online=bool(row.get("Online", False)),
            s3_path=row.get("S3Path"),
            content_start=datetime.fromisoformat(start.replace("Z", "+00:00")) if start else None,
            raw=row,
        )
