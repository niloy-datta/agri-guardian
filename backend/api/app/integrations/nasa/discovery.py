"""Keyless NASA discovery APIs: Earthdata CMR, EONET and ASF Search.

All three were exercised live while writing this module:

- CMR: `/search/collections.json` and `/search/granules.json` return
  `{"feed": {"entry": [...]}}`; collection entries carry `id`, `title`,
  `short_name`, `version_id`.
- EONET v3: `/events` returns `{"events": [{id, title, categories[],
  geometry[{date, type, coordinates, magnitudeValue?}], closed}]}`.
- ASF Search: `/services/search/param?output=json` returns a list of
  lists of scene dicts (`granuleName`, `startTime`, `platform`,
  `flightDirection`, `polarization`, `processingLevel`, `sizeMB`,
  `downloadUrl`, `centerLat`, `centerLon`, ...). Note the latest scenes
  can be `METADATA_RAW`; request an explicit `processingLevel` (e.g.
  `GRD_HD`) for usable products.

Downloading data from any of these needs an Earthdata token; this module
only discovers it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from app.integrations.common.errors import IntegrationResponseError, IntegrationValidationError
from app.integrations.common.geo import (
    validate_bbox,
    validate_date_range,
    validate_lat_lon,
)
from app.integrations.common.http import Provenance, ProviderHttp

# --------------------------------------------------------------------------
# CMR
# --------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class CmrCollection:
    concept_id: str
    short_name: str
    version: str | None
    title: str
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class CmrGranule:
    concept_id: str
    title: str
    time_start: str | None
    time_end: str | None
    links: list[str]
    raw: dict[str, Any] = field(repr=False)


class CmrClient:
    PROVIDER = "NASA CMR"

    def __init__(self, *, base_url: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._http = http

    async def search_collections(
        self, *, short_name: str | None = None, keyword: str | None = None, page_size: int = 10
    ) -> tuple[list[CmrCollection], Provenance]:
        if not short_name and not keyword:
            raise IntegrationValidationError(
                "provide short_name or keyword", provider=self.PROVIDER
            )
        self._page_size(page_size)
        params: dict[str, Any] = {"page_size": page_size}
        if short_name:
            params["short_name"] = short_name
        if keyword:
            params["keyword"] = keyword
        result = await self._http.get(
            f"{self._base}/collections.json", dataset="CMR collections", params=params
        )
        entries = self._entries(result.json())
        collections = [
            CmrCollection(
                concept_id=str(e["id"]),
                short_name=str(e.get("short_name", "")),
                version=e.get("version_id"),
                title=str(e.get("title", "")),
                raw=e,
            )
            for e in entries
        ]
        return collections, result.provenance

    async def search_granules(
        self,
        *,
        collection_concept_id: str | None = None,
        short_name: str | None = None,
        bbox: tuple[float, float, float, float] | None = None,
        start: date | None = None,
        end: date | None = None,
        page_size: int = 20,
    ) -> tuple[list[CmrGranule], Provenance]:
        if not collection_concept_id and not short_name:
            raise IntegrationValidationError(
                "provide collection_concept_id or short_name", provider=self.PROVIDER
            )
        self._page_size(page_size)
        params: dict[str, Any] = {"page_size": page_size}
        if collection_concept_id:
            params["collection_concept_id"] = collection_concept_id
        if short_name:
            params["short_name"] = short_name
        if bbox:
            west, south, east, north = validate_bbox(*bbox, provider=self.PROVIDER)
            params["bounding_box"] = f"{west},{south},{east},{north}"
        if start and end:
            validate_date_range(start, end, provider=self.PROVIDER)
            params["temporal"] = f"{start.isoformat()}T00:00:00Z,{end.isoformat()}T23:59:59Z"
        result = await self._http.get(
            f"{self._base}/granules.json", dataset="CMR granules", params=params
        )
        granules = [
            CmrGranule(
                concept_id=str(e["id"]),
                title=str(e.get("title", "")),
                time_start=e.get("time_start"),
                time_end=e.get("time_end"),
                links=[str(link["href"]) for link in e.get("links", []) if "href" in link],
                raw=e,
            )
            for e in self._entries(result.json())
        ]
        return granules, result.provenance

    @staticmethod
    def _entries(payload: Any) -> list[dict[str, Any]]:
        try:
            return list(payload["feed"]["entry"])
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"CMR response missing feed.entry: {exc}", provider=CmrClient.PROVIDER
            ) from exc

    def _page_size(self, page_size: int) -> None:
        if not 1 <= page_size <= 2000:
            raise IntegrationValidationError("page_size must be 1-2000", provider=self.PROVIDER)


# --------------------------------------------------------------------------
# EONET
# --------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class EonetEvent:
    id: str
    title: str
    categories: list[str]
    closed: str | None
    latest_date: str | None
    latest_coordinates: list[float] | None
    """[lon, lat] for a Point geometry; None for polygons."""
    link: str | None
    raw: dict[str, Any] = field(repr=False)


class EonetClient:
    PROVIDER = "NASA EONET"

    def __init__(self, *, base_url: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._http = http

    async def list_events(
        self,
        *,
        status: str = "open",
        category: str | None = None,
        days: int | None = None,
        bbox: tuple[float, float, float, float] | None = None,
        limit: int = 50,
    ) -> tuple[list[EonetEvent], Provenance]:
        """`category` is an EONET category id (floods, severeStorms, drought...).
        `bbox` is (west, south, east, north); EONET wants upper-left then
        lower-right, which this method converts."""
        if status not in ("open", "closed", "all"):
            raise IntegrationValidationError(
                "status must be open, closed or all", provider=self.PROVIDER
            )
        if limit < 1:
            raise IntegrationValidationError("limit must be >= 1", provider=self.PROVIDER)
        params: dict[str, Any] = {"status": status, "limit": limit}
        if category:
            params["category"] = category
        if days:
            params["days"] = days
        if bbox:
            west, south, east, north = validate_bbox(*bbox, provider=self.PROVIDER)
            params["bbox"] = f"{west},{north},{east},{south}"
        result = await self._http.get(
            f"{self._base}/events", dataset="EONET events", params=params
        )
        payload = result.json()
        events_raw = payload.get("events") if isinstance(payload, dict) else None
        if not isinstance(events_raw, list):
            raise IntegrationResponseError("EONET response has no events", provider=self.PROVIDER)
        return [self._parse(e) for e in events_raw], result.provenance

    @staticmethod
    def _parse(event: dict[str, Any]) -> EonetEvent:
        geometry = event.get("geometry") or []
        latest = geometry[-1] if geometry else None
        coords = latest.get("coordinates") if latest and latest.get("type") == "Point" else None
        return EonetEvent(
            id=str(event["id"]),
            title=str(event.get("title", "")),
            categories=[str(c.get("id")) for c in event.get("categories", [])],
            closed=event.get("closed"),
            latest_date=latest.get("date") if latest else None,
            latest_coordinates=[float(c) for c in coords] if coords else None,
            link=event.get("link"),
            raw=event,
        )


# --------------------------------------------------------------------------
# ASF Search (Sentinel-1 radar)
# --------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class AsfScene:
    granule_name: str
    start_time: datetime | None
    platform: str | None
    flight_direction: str | None
    polarization: str | None
    processing_level: str | None
    beam_mode: str | None
    size_mb: float | None
    download_url: str | None
    center_lat: float | None
    center_lon: float | None
    raw: dict[str, Any] = field(repr=False)


class AsfClient:
    PROVIDER = "ASF Search"

    def __init__(self, *, base_url: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._http = http

    async def search_sentinel1(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date | None = None,
        end: date | None = None,
        processing_level: str = "GRD_HD",
        beam_mode: str = "IW",
        max_results: int = 20,
    ) -> tuple[list[AsfScene], Provenance]:
        validate_lat_lon(latitude, longitude, provider=self.PROVIDER)
        if not 1 <= max_results <= 2000:
            raise IntegrationValidationError("max_results must be 1-2000", provider=self.PROVIDER)
        params: dict[str, Any] = {
            "platform": "SENTINEL-1",
            "processingLevel": processing_level,
            "beamMode": beam_mode,
            "intersectsWith": f"point({longitude} {latitude})",
            "maxResults": max_results,
            "output": "json",
        }
        if start and end:
            validate_date_range(start, end, provider=self.PROVIDER)
            params["start"] = f"{start.isoformat()}T00:00:00Z"
            params["end"] = f"{end.isoformat()}T23:59:59Z"
        result = await self._http.get(
            f"{self._base}/services/search/param", dataset="ASF Sentinel-1", params=params
        )
        payload = result.json()
        if not isinstance(payload, list):
            raise IntegrationResponseError("ASF response was not a list", provider=self.PROVIDER)
        flat = payload[0] if payload and isinstance(payload[0], list) else payload
        return [self._parse(s) for s in flat], result.provenance

    @staticmethod
    def _parse(scene: dict[str, Any]) -> AsfScene:
        start = scene.get("startTime")
        return AsfScene(
            granule_name=str(scene.get("granuleName", "")),
            start_time=datetime.fromisoformat(start.replace("Z", "+00:00")) if start else None,
            platform=scene.get("platform"),
            flight_direction=scene.get("flightDirection"),
            polarization=scene.get("polarization"),
            processing_level=scene.get("processingLevel"),
            beam_mode=scene.get("beamMode"),
            size_mb=float(scene["sizeMB"]) if scene.get("sizeMB") is not None else None,
            download_url=scene.get("downloadUrl"),
            center_lat=_f(scene.get("centerLat")),
            center_lon=_f(scene.get("centerLon")),
            raw=scene,
        )


def _f(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
