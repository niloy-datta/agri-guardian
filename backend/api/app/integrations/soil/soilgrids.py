"""ISRIC SoilGrids: REST point query and WCS raster subsets.

Verified live:

- REST `GET /soilgrids/v2.0/properties/query?lon=&lat=&property=&depth=&value=mean`
  returns `properties.layers[].depths[].values.{mean}` plus
  `unit_measure.d_factor` (phh2o 10, soc 10, nitrogen 100). Stored values
  are integers; the real value is `stored / d_factor`.
- **The REST point query returned `null` for every property at both
  Bangladesh points tried (Rajshahi 24.37N 88.6E and Dhaka 23.8N 90.4E)**,
  so `fetch_point` reports `has_data=False` rather than a fabricated
  number. The WCS raster for the same area *does* have values, so use
  `fetch_wcs_stats` for Bangladesh.
- WCS `GetCoverage` (`map=/map/<property>.map`, `COVERAGEID=phh2o_0-5cm_mean`,
  `FORMAT=image/tiff`, `SUBSET=Lat(..)`, `SUBSET=Long(..)`) returned a valid
  GeoTIFF; a 0.1 degree box around Rajshahi decoded to a 42x44 int16 grid
  with pH*10 values of 67-71 (pH 6.7-7.1). Value `0` is the no-data value
  for phh2o in that raster.

Only `phh2o`, `soc` and `nitrogen` have verified `d_factor`s; any other
property needs an explicit `d_factor` so a wrong scale can never be applied
silently.
"""

from __future__ import annotations

import io
import re
import statistics
from dataclasses import dataclass, field
from typing import Any

from app.integrations.common.errors import (
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import validate_bbox, validate_lat_lon
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "ISRIC SoilGrids"
VERIFIED_D_FACTORS: dict[str, int] = {"phh2o": 10, "soc": 10, "nitrogen": 100}
VERIFIED_NODATA: dict[str, int] = {"phh2o": 0}
_PROPERTY_RE = re.compile(r"^[a-z0-9]+$")
_DEPTH_RE = re.compile(r"^\d+-\d+cm$")
_VALUE_RE = re.compile(r"^(mean|Q0\.05|Q0\.5|Q0\.95|uncertainty)$")


@dataclass(frozen=True, slots=True)
class SoilLayerValue:
    property: str
    depth: str
    stat: str
    value: float | None
    """Scaled to real units (stored / d_factor); None when SoilGrids has no data."""
    unit: str | None
    """The real-world unit (`target_units`), e.g. '-' for pH, 'g/kg' for soc."""


@dataclass(frozen=True, slots=True)
class SoilPointResult:
    values: list[SoilLayerValue]
    has_data: bool
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class SoilRasterStats:
    property: str
    depth: str
    stat: str
    valid_pixels: int
    total_pixels: int
    mean: float | None
    median: float | None
    minimum: float | None
    maximum: float | None
    d_factor: int
    nodata_value: int | None
    provenance: Provenance


class SoilGridsClient:
    def __init__(self, *, rest_url: str, wcs_url: str, http: ProviderHttp) -> None:
        self._rest = rest_url.rstrip("/")
        self._wcs = wcs_url
        self._http = http

    async def fetch_point(
        self,
        *,
        latitude: float,
        longitude: float,
        properties: tuple[str, ...] = ("phh2o", "soc", "nitrogen"),
        depths: tuple[str, ...] = ("0-5cm", "5-15cm"),
        stat: str = "mean",
    ) -> SoilPointResult:
        validate_lat_lon(latitude, longitude, provider=PROVIDER)
        for prop in properties:
            if not _PROPERTY_RE.match(prop):
                raise IntegrationValidationError(f"invalid property {prop!r}", provider=PROVIDER)
        for depth in depths:
            if not _DEPTH_RE.match(depth):
                raise IntegrationValidationError(f"invalid depth {depth!r}", provider=PROVIDER)
        if not _VALUE_RE.match(stat):
            raise IntegrationValidationError(f"invalid stat {stat!r}", provider=PROVIDER)
        if not properties or not depths:
            raise IntegrationValidationError("properties and depths are required", provider=PROVIDER)

        params: list[tuple[str, Any]] = [("lat", latitude), ("lon", longitude)]
        params += [("property", p) for p in properties]
        params += [("depth", d) for d in depths]
        params.append(("value", stat))
        result = await self._http.get(
            f"{self._rest}/properties/query",
            dataset="SoilGrids properties",
            params=params,
        )
        payload = result.json()
        try:
            layers = payload["properties"]["layers"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"SoilGrids response missing layers: {exc}", provider=PROVIDER
            ) from exc

        values: list[SoilLayerValue] = []
        for layer in layers:
            unit_measure = layer.get("unit_measure") or {}
            d_factor = unit_measure.get("d_factor") or 1
            for depth in layer.get("depths", []):
                for stat_name, raw_value in (depth.get("values") or {}).items():
                    values.append(
                        SoilLayerValue(
                            property=str(layer["name"]),
                            depth=str(depth["label"]),
                            stat=stat_name,
                            value=None if raw_value is None else float(raw_value) / d_factor,
                            unit=unit_measure.get("target_units"),
                        )
                    )
        return SoilPointResult(
            values=values,
            has_data=any(v.value is not None for v in values),
            provenance=result.provenance,
            raw=payload,
        )

    async def fetch_wcs_geotiff(
        self,
        *,
        property: str,
        depth: str,
        bbox: tuple[float, float, float, float],
        stat: str = "mean",
    ) -> tuple[bytes, Provenance]:
        """Raw GeoTIFF bytes for a small bbox (west, south, east, north)."""
        west, south, east, north = validate_bbox(*bbox, provider=PROVIDER)
        if not _PROPERTY_RE.match(property) or not _DEPTH_RE.match(depth):
            raise IntegrationValidationError("invalid property/depth", provider=PROVIDER)
        if not _VALUE_RE.match(stat):
            raise IntegrationValidationError(f"invalid stat {stat!r}", provider=PROVIDER)
        if (east - west) > 2.0 or (north - south) > 2.0:
            raise IntegrationValidationError(
                "bbox larger than 2 degrees; request a field-sized area", provider=PROVIDER
            )
        params: list[tuple[str, Any]] = [
            ("map", f"/map/{property}.map"),
            ("SERVICE", "WCS"),
            ("VERSION", "2.0.1"),
            ("REQUEST", "GetCoverage"),
            ("COVERAGEID", f"{property}_{depth}_{stat}"),
            ("FORMAT", "image/tiff"),
            ("SUBSETTINGCRS", "http://www.opengis.net/def/crs/EPSG/0/4326"),
            ("SUBSET", f"Lat({south},{north})"),
            ("SUBSET", f"Long({west},{east})"),
        ]
        result = await self._http.get(
            self._wcs,
            dataset=f"SoilGrids WCS {property} {depth}",
            params=params,
        )
        content = result.content
        if content[:2] not in (b"II", b"MM"):
            # MapServer reports errors as XML/HTML with HTTP 200.
            raise IntegrationResponseError(
                f"WCS did not return a TIFF: {content[:200]!r}", provider=PROVIDER
            )
        return content, result.provenance

    async def fetch_wcs_stats(
        self,
        *,
        property: str,
        depth: str,
        bbox: tuple[float, float, float, float],
        stat: str = "mean",
        d_factor: int | None = None,
        nodata_value: int | None = None,
    ) -> SoilRasterStats:
        """Fetches the raster and summarizes it in real units."""
        scale = d_factor if d_factor is not None else VERIFIED_D_FACTORS.get(property)
        if scale is None:
            raise IntegrationValidationError(
                f"no verified d_factor for {property!r}; pass d_factor explicitly",
                provider=PROVIDER,
            )
        nodata = nodata_value if nodata_value is not None else VERIFIED_NODATA.get(property)
        content, provenance = await self.fetch_wcs_geotiff(
            property=property, depth=depth, bbox=bbox, stat=stat
        )
        return summarize_geotiff(
            content,
            property=property,
            depth=depth,
            stat=stat,
            d_factor=scale,
            nodata_value=nodata,
            provenance=provenance,
        )


def summarize_geotiff(
    content: bytes,
    *,
    property: str,
    depth: str,
    stat: str,
    d_factor: int,
    nodata_value: int | None,
    provenance: Provenance,
) -> SoilRasterStats:
    import tifffile

    try:
        with tifffile.TiffFile(io.BytesIO(content)) as tif:
            array = tif.pages[0].asarray()
    except Exception as exc:  # tifffile raises several unrelated types
        raise IntegrationResponseError(
            f"could not decode GeoTIFF: {exc}", provider=PROVIDER
        ) from exc
    flat = [int(v) for v in array.ravel()]
    valid = [v for v in flat if nodata_value is None or v != nodata_value]
    scaled = [v / d_factor for v in valid]
    return SoilRasterStats(
        property=property,
        depth=depth,
        stat=stat,
        valid_pixels=len(valid),
        total_pixels=len(flat),
        mean=statistics.fmean(scaled) if scaled else None,
        median=statistics.median(scaled) if scaled else None,
        minimum=min(scaled) if scaled else None,
        maximum=max(scaled) if scaled else None,
        d_factor=d_factor,
        nodata_value=nodata_value,
        provenance=provenance,
    )
