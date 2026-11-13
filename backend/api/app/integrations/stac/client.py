"""STAC API client for Earth Search, Microsoft Planetary Computer and the
Copernicus Data Space STAC catalogue.

Verified live:
- Earth Search and Planetary Computer accept `POST /search` with
  `collections`, `bbox`, `datetime`, `limit` and a `query` filter
  (`{"eo:cloud_cover": {"lt": 30}}`), and return `next` links with
  `method: POST`.
- The CDSE catalogue answers `GET /collections/{id}/items` (bbox,
  datetime, limit). Its `POST /search` returned HTTP 502 when tried, so
  `CdseStacClient` uses the collection-items route instead.
- Planetary Computer assets are Azure blobs that need a short-lived SAS
  token: `GET /sas/v1/sign?href=...` returned a signed `href` plus
  `msft:expiry`.

Cloud cover is always also enforced client-side so the three catalogues
behave identically.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

from app.integrations.common.errors import IntegrationResponseError, IntegrationValidationError
from app.integrations.common.geo import validate_bbox
from app.integrations.common.http import Provenance, ProviderHttp

_MAX_PAGES = 20


@dataclass(frozen=True, slots=True)
class StacItem:
    id: str
    collection: str | None
    datetime: datetime | None
    bbox: tuple[float, ...] | None
    cloud_cover: float | None
    assets: dict[str, str]
    """asset key -> href."""
    properties: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class StacSearchResult:
    items: list[StacItem]
    provenance: Provenance
    truncated: bool
    """True when `limit` stopped paging while the server had more."""


class StacClient:
    def __init__(self, *, provider: str, base_url: str, http: ProviderHttp) -> None:
        self.provider = provider
        self._base = base_url.rstrip("/")
        self._http = http

    async def search(
        self,
        *,
        collection: str,
        bbox: tuple[float, float, float, float],
        start: datetime,
        end: datetime,
        max_cloud_cover: float | None = None,
        limit: int = 20,
    ) -> StacSearchResult:
        self._validate(bbox, start, end, limit)
        body: dict[str, Any] = {
            "collections": [collection],
            "bbox": list(bbox),
            "datetime": _interval(start, end),
            "limit": min(limit, 100),
        }
        if max_cloud_cover is not None:
            body["query"] = {"eo:cloud_cover": {"lt": max_cloud_cover}}
        return await self._paged(
            first=("POST", f"{self._base}/search", body, None),
            limit=limit,
            max_cloud_cover=max_cloud_cover,
            dataset=f"STAC {collection}",
        )

    async def _paged(
        self,
        *,
        first: tuple[str, str, dict[str, Any] | None, dict[str, Any] | None],
        limit: int,
        max_cloud_cover: float | None,
        dataset: str,
    ) -> StacSearchResult:
        method, url, body, params = first
        items: list[StacItem] = []
        provenance: Provenance | None = None
        truncated = False
        for _ in range(_MAX_PAGES):
            result = await self._http.request(
                method, url, dataset=dataset, json_body=body, params=params
            )
            provenance = provenance or result.provenance
            page = result.json()
            features = page.get("features") if isinstance(page, dict) else None
            if not isinstance(features, list):
                raise IntegrationResponseError(
                    "STAC response has no features array", provider=self.provider
                )
            for feature in features:
                item = _parse_item(feature, self.provider)
                if (
                    max_cloud_cover is not None
                    and item.cloud_cover is not None
                    and item.cloud_cover >= max_cloud_cover
                ):
                    continue
                items.append(item)
            nxt = next((link for link in page.get("links", []) if link.get("rel") == "next"), None)
            if len(items) >= limit:
                truncated = nxt is not None or len(items) > limit
                items = items[:limit]
                break
            if nxt is None:
                break
            method = str(nxt.get("method", "GET")).upper()
            url = nxt["href"]
            body = nxt.get("body") if method == "POST" else None
            params = None
        else:
            truncated = True
        assert provenance is not None
        return StacSearchResult(items=items, provenance=provenance, truncated=truncated)

    def _validate(
        self, bbox: tuple[float, float, float, float], start: datetime, end: datetime, limit: int
    ) -> None:
        validate_bbox(*bbox, provider=self.provider)
        if start > end:
            raise IntegrationValidationError("start must be <= end", provider=self.provider)
        if limit < 1:
            raise IntegrationValidationError("limit must be >= 1", provider=self.provider)


class CdseStacClient(StacClient):
    """CDSE STAC: collection-items route (its `POST /search` was a 502)."""

    async def search(
        self,
        *,
        collection: str,
        bbox: tuple[float, float, float, float],
        start: datetime,
        end: datetime,
        max_cloud_cover: float | None = None,
        limit: int = 20,
    ) -> StacSearchResult:
        self._validate(bbox, start, end, limit)
        params = {
            "bbox": ",".join(str(v) for v in bbox),
            "datetime": _interval(start, end),
            "limit": min(limit, 100),
        }
        return await self._paged(
            first=("GET", f"{self._base}/collections/{collection}/items", None, params),
            limit=limit,
            max_cloud_cover=max_cloud_cover,
            dataset=f"CDSE STAC {collection}",
        )


class PlanetaryComputerStacClient(StacClient):
    """Adds SAS signing so asset hrefs can actually be downloaded."""

    def __init__(self, *, base_url: str, sas_url: str, http: ProviderHttp) -> None:
        super().__init__(provider="Planetary Computer", base_url=base_url, http=http)
        self._sas_url = sas_url

    async def sign_href(self, href: str) -> tuple[str, str | None]:
        """Returns (signed_href, expiry ISO string or None)."""
        result = await self._http.get(self._sas_url, dataset="PC SAS", params={"href": href})
        body = result.json()
        signed = body.get("href") if isinstance(body, dict) else None
        if not signed:
            raise IntegrationResponseError("SAS response had no href", provider=self.provider)
        return str(signed), body.get("msft:expiry")


def _interval(start: datetime, end: datetime) -> str:
    return f"{start.strftime('%Y-%m-%dT%H:%M:%SZ')}/{end.strftime('%Y-%m-%dT%H:%M:%SZ')}"


def _parse_item(feature: dict[str, Any], provider: str) -> StacItem:
    try:
        item_id = str(feature["id"])
    except (KeyError, TypeError) as exc:
        raise IntegrationResponseError("STAC feature has no id", provider=provider) from exc
    props = feature.get("properties") or {}
    stamp = props.get("datetime")
    parsed: datetime | None = None
    if stamp:
        parsed = datetime.fromisoformat(str(stamp).replace("Z", "+00:00"))
    cloud = props.get("eo:cloud_cover")
    bbox = feature.get("bbox")
    return StacItem(
        id=item_id,
        collection=feature.get("collection"),
        datetime=parsed,
        bbox=tuple(float(v) for v in bbox) if bbox else None,
        cloud_cover=float(cloud) if cloud is not None else None,
        assets={
            key: str(asset["href"])
            for key, asset in (feature.get("assets") or {}).items()
            if isinstance(asset, dict) and "href" in asset
        },
        properties=props,
    )
