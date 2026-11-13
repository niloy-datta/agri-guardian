"""Sentinel Hub Processing, Statistical and Catalog APIs (NDVI for fields).

Defaults to the Copernicus Data Space deployment (`sh.dataspace.copernicus.eu`),
authenticated with the CDSE OAuth client. The request bodies follow Sentinel
Hub's documented v1 API: `POST /api/v1/process` (raster out),
`POST /api/v1/statistics` (per-interval stats for a polygon) and
`POST /api/v1/catalog/1.0.0/search` (STAC-style scene search).

**Unverified against a live account.** All three need an OAuth bearer token
that was not available while writing this, so the request builders and the
response parsers are covered by tests against *documented-shape* fixtures,
not captured responses. Use `scripts/integration_smoke.py` with
`copernicus_client_id/secret` set to confirm them against the live service
before relying on the numbers.

Cloud handling: Sentinel-2 L2A `SCL` classes 0 (no data), 1 (saturated),
3 (cloud shadow), 8/9 (cloud) and 10 (thin cirrus) are masked out of the
NDVI so a cloudy pixel is "no data", never a misleading low NDVI. Snow (11)
is also excluded.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import (
    polygon_bbox,
    validate_bbox,
    validate_date_range,
    validate_polygon_geojson,
)
from app.integrations.common.http import Provenance, ProviderHttp
from app.integrations.common.oauth import ClientCredentialsTokenSource

PROVIDER = "Sentinel Hub"
S2_L2A = "sentinel-2-l2a"
_CRS_4326 = "http://www.opengis.net/def/crs/EPSG/0/4326"
_MASKED_SCL = (0, 1, 3, 8, 9, 10, 11)

NDVI_PROCESS_EVALSCRIPT = """//VERSION=3
function setup() {
  return {
    input: [{ bands: ["B04", "B08", "SCL", "dataMask"] }],
    output: { bands: 1, sampleType: "FLOAT32" }
  };
}
function evaluatePixel(s) {
  var bad = [0, 1, 3, 8, 9, 10, 11].indexOf(s.SCL) !== -1;
  if (bad || s.dataMask === 0) { return [NaN]; }
  return [(s.B08 - s.B04) / (s.B08 + s.B04)];
}
"""

NDVI_STATISTICS_EVALSCRIPT = """//VERSION=3
function setup() {
  return {
    input: [{ bands: ["B04", "B08", "SCL", "dataMask"] }],
    output: [
      { id: "ndvi", bands: 1, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1 }
    ]
  };
}
function evaluatePixel(s) {
  var bad = [0, 1, 3, 8, 9, 10, 11].indexOf(s.SCL) !== -1;
  var ok = (bad || s.dataMask === 0) ? 0 : 1;
  return { ndvi: [(s.B08 - s.B04) / (s.B08 + s.B04)], dataMask: [ok] };
}
"""


@dataclass(frozen=True, slots=True)
class NdviObservation:
    start: datetime
    end: datetime
    mean: float
    std_dev: float | None
    minimum: float | None
    maximum: float | None
    sample_count: int
    no_data_count: int

    @property
    def valid_fraction(self) -> float:
        return 0.0 if self.sample_count == 0 else 1 - self.no_data_count / self.sample_count


@dataclass(frozen=True, slots=True)
class NdviTimeSeries:
    observations: list[NdviObservation]
    skipped_intervals: int
    """Intervals with no usable pixels (fully cloudy/no data) - never zeros."""
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class CatalogScene:
    id: str
    datetime: datetime | None
    cloud_cover: float | None
    raw: dict[str, Any] = field(repr=False)


class SentinelHubClient:
    def __init__(
        self,
        *,
        base_url: str,
        token_source: ClientCredentialsTokenSource | None,
        http: ProviderHttp,
    ) -> None:
        self._base = base_url.rstrip("/")
        self._tokens = token_source
        self._http = http

    # -- Processing API --------------------------------------------------

    def build_ndvi_process_request(
        self,
        *,
        bbox: tuple[float, float, float, float],
        start: date,
        end: date,
        width: int = 256,
        height: int = 256,
        max_cloud_cover: float = 40.0,
    ) -> dict[str, Any]:
        validate_bbox(*bbox, provider=PROVIDER)
        validate_date_range(start, end, provider=PROVIDER)
        if not (1 <= width <= 2500 and 1 <= height <= 2500):
            raise IntegrationValidationError("width/height must be 1-2500", provider=PROVIDER)
        return {
            "input": {
                "bounds": {"bbox": list(bbox), "properties": {"crs": _CRS_4326}},
                "data": [
                    {
                        "type": S2_L2A,
                        "dataFilter": {
                            "timeRange": _time_range(start, end),
                            "mosaickingOrder": "leastCC",
                            "maxCloudCoverage": max_cloud_cover,
                        },
                    }
                ],
            },
            "output": {
                "width": width,
                "height": height,
                "responses": [{"identifier": "default", "format": {"type": "image/tiff"}}],
            },
            "evalscript": NDVI_PROCESS_EVALSCRIPT,
        }

    async def fetch_ndvi_raster(
        self,
        *,
        bbox: tuple[float, float, float, float],
        start: date,
        end: date,
        width: int = 256,
        height: int = 256,
        max_cloud_cover: float = 40.0,
    ) -> bytes:
        """Float32 GeoTIFF of NDVI (NaN where cloudy/no data)."""
        body = self.build_ndvi_process_request(
            bbox=bbox,
            start=start,
            end=end,
            width=width,
            height=height,
            max_cloud_cover=max_cloud_cover,
        )
        result = await self._http.post(
            f"{self._base}/api/v1/process",
            dataset="Sentinel Hub Processing",
            json_body=body,
            headers={"Accept": "image/tiff"},
            bearer=await self._token(),
        )
        return result.content

    # -- Statistical API -------------------------------------------------

    def build_ndvi_statistics_request(
        self,
        *,
        polygon: dict[str, Any],
        start: date,
        end: date,
        interval_days: int = 5,
        max_cloud_cover: float = 60.0,
        resolution_deg: float = 0.0001,
    ) -> dict[str, Any]:
        validate_polygon_geojson(polygon, provider=PROVIDER)
        validate_date_range(start, end, provider=PROVIDER)
        if not 1 <= interval_days <= 365:
            raise IntegrationValidationError("interval_days must be 1-365", provider=PROVIDER)
        return {
            "input": {
                "bounds": {"geometry": polygon, "properties": {"crs": _CRS_4326}},
                "data": [
                    {
                        "type": S2_L2A,
                        "dataFilter": {
                            "mosaickingOrder": "leastCC",
                            "maxCloudCoverage": max_cloud_cover,
                        },
                    }
                ],
            },
            "aggregation": {
                "timeRange": _time_range(start, end),
                "aggregationInterval": {"of": f"P{interval_days}D"},
                "evalscript": NDVI_STATISTICS_EVALSCRIPT,
                "resx": resolution_deg,
                "resy": resolution_deg,
            },
            "calculations": {"default": {}},
        }

    async def fetch_ndvi_time_series(
        self,
        *,
        polygon: dict[str, Any],
        start: date,
        end: date,
        interval_days: int = 5,
        max_cloud_cover: float = 60.0,
    ) -> NdviTimeSeries:
        """Field-level NDVI per interval over a polygon (the field boundary)."""
        body = self.build_ndvi_statistics_request(
            polygon=polygon,
            start=start,
            end=end,
            interval_days=interval_days,
            max_cloud_cover=max_cloud_cover,
        )
        result = await self._http.post(
            f"{self._base}/api/v1/statistics",
            dataset="Sentinel Hub Statistical",
            json_body=body,
            bearer=await self._token(),
        )
        payload = result.json()
        observations, skipped = parse_ndvi_statistics(payload)
        return NdviTimeSeries(
            observations=observations,
            skipped_intervals=skipped,
            provenance=result.provenance,
            raw=payload,
        )

    # -- Catalog API -----------------------------------------------------

    async def search_catalog(
        self,
        *,
        polygon: dict[str, Any],
        start: date,
        end: date,
        max_cloud_cover: float = 40.0,
        limit: int = 50,
    ) -> list[CatalogScene]:
        validate_polygon_geojson(polygon, provider=PROVIDER)
        validate_date_range(start, end, provider=PROVIDER)
        body = {
            "bbox": list(polygon_bbox(polygon)),
            "datetime": f"{start.isoformat()}T00:00:00Z/{end.isoformat()}T23:59:59Z",
            "collections": [S2_L2A],
            "limit": limit,
            "filter": f"eo:cloud_cover < {max_cloud_cover}",
            "filter-lang": "cql2-text",
        }
        result = await self._http.post(
            f"{self._base}/api/v1/catalog/1.0.0/search",
            dataset="Sentinel Hub Catalog",
            json_body=body,
            bearer=await self._token(),
        )
        payload = result.json()
        features = payload.get("features") if isinstance(payload, dict) else None
        if not isinstance(features, list):
            raise IntegrationResponseError("catalog response has no features", provider=PROVIDER)
        scenes = []
        for feature in features:
            props = feature.get("properties") or {}
            stamp = props.get("datetime")
            cloud = props.get("eo:cloud_cover")
            scenes.append(
                CatalogScene(
                    id=str(feature["id"]),
                    datetime=datetime.fromisoformat(stamp.replace("Z", "+00:00")) if stamp else None,
                    cloud_cover=float(cloud) if cloud is not None else None,
                    raw=feature,
                )
            )
        return scenes

    async def _token(self) -> str:
        if self._tokens is None:
            raise IntegrationCredentialsMissingError(
                "Sentinel Hub OAuth client (copernicus_client_id/secret) is not configured",
                provider=PROVIDER,
            )
        return await self._tokens.get_token()


def parse_ndvi_statistics(payload: Any) -> tuple[list[NdviObservation], int]:
    """Parses a Statistical API response for the `ndvi` output. Intervals
    with no valid pixels are counted as skipped rather than reported as 0."""
    try:
        intervals = payload["data"]
    except (KeyError, TypeError) as exc:
        raise IntegrationResponseError(
            f"statistics response has no data: {exc}", provider=PROVIDER
        ) from exc
    observations: list[NdviObservation] = []
    skipped = 0
    for entry in intervals:
        try:
            stats = entry["outputs"]["ndvi"]["bands"]["B0"]["stats"]
            window = entry["interval"]
            start = datetime.fromisoformat(window["from"].replace("Z", "+00:00"))
            end = datetime.fromisoformat(window["to"].replace("Z", "+00:00"))
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"statistics interval malformed: {exc}", provider=PROVIDER
            ) from exc
        sample_count = int(stats.get("sampleCount", 0))
        no_data = int(stats.get("noDataCount", 0))
        mean = stats.get("mean")
        if mean is None or str(mean) == "NaN" or sample_count == 0 or no_data >= sample_count:
            skipped += 1
            continue
        observations.append(
            NdviObservation(
                start=start,
                end=end,
                mean=float(mean),
                std_dev=_opt(stats.get("stDev")),
                minimum=_opt(stats.get("min")),
                maximum=_opt(stats.get("max")),
                sample_count=sample_count,
                no_data_count=no_data,
            )
        )
    return observations, skipped


def _opt(value: Any) -> float | None:
    if value is None or str(value) == "NaN":
        return None
    return float(value)


def _time_range(start: date, end: date) -> dict[str, str]:
    return {"from": f"{start.isoformat()}T00:00:00Z", "to": f"{end.isoformat()}T23:59:59Z"}
