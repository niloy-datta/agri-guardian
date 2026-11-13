"""Request-side validation shared by every integration client.

Everything here runs before a network call so a bad coordinate fails fast
with a clear message instead of a provider-specific 4xx.
"""

from __future__ import annotations

from datetime import date
from typing import Any

from app.integrations.common.errors import IntegrationValidationError

# A deliberately generous box around Bangladesh (country spans roughly
# 20.6-26.7N, 88.0-92.7E). Used only for optional sanity checks, never to
# reject a globally valid coordinate by default.
BANGLADESH_BBOX = (88.0, 20.5, 92.8, 26.8)


def validate_lat_lon(latitude: float, longitude: float, *, provider: str = "") -> None:
    if not -90.0 <= latitude <= 90.0:
        raise IntegrationValidationError(
            f"latitude {latitude} out of range [-90, 90]", provider=provider
        )
    if not -180.0 <= longitude <= 180.0:
        raise IntegrationValidationError(
            f"longitude {longitude} out of range [-180, 180]", provider=provider
        )


def validate_bbox(
    west: float, south: float, east: float, north: float, *, provider: str = ""
) -> tuple[float, float, float, float]:
    """Validates a (west, south, east, north) box. A box crossing the
    antimeridian is not supported - none of this project's fields do."""
    validate_lat_lon(south, west, provider=provider)
    validate_lat_lon(north, east, provider=provider)
    if west >= east:
        raise IntegrationValidationError(
            f"bbox west ({west}) must be < east ({east})", provider=provider
        )
    if south >= north:
        raise IntegrationValidationError(
            f"bbox south ({south}) must be < north ({north})", provider=provider
        )
    return (west, south, east, north)


def validate_date_range(start: date, end: date, *, provider: str = "") -> None:
    if start > end:
        raise IntegrationValidationError(
            f"start ({start}) must be <= end ({end})", provider=provider
        )


def validate_polygon_geojson(geometry: dict[str, Any], *, provider: str = "") -> dict[str, Any]:
    """Validates a GeoJSON Polygon/MultiPolygon: closed rings, in-range
    coordinates. Returns the geometry unchanged."""
    gtype = geometry.get("type")
    coords = geometry.get("coordinates")
    if gtype not in ("Polygon", "MultiPolygon") or not isinstance(coords, list):
        raise IntegrationValidationError(
            "geometry must be a GeoJSON Polygon or MultiPolygon", provider=provider
        )
    polygons = [coords] if gtype == "Polygon" else coords
    for polygon in polygons:
        if not polygon:
            raise IntegrationValidationError("polygon has no rings", provider=provider)
        for ring in polygon:
            if len(ring) < 4:
                raise IntegrationValidationError(
                    "polygon ring needs at least 4 positions", provider=provider
                )
            if list(ring[0]) != list(ring[-1]):
                raise IntegrationValidationError("polygon ring is not closed", provider=provider)
            for position in ring:
                validate_lat_lon(position[1], position[0], provider=provider)
    return geometry


def polygon_bbox(geometry: dict[str, Any]) -> tuple[float, float, float, float]:
    """(west, south, east, north) of a validated Polygon/MultiPolygon."""
    gtype = geometry["type"]
    polygons = [geometry["coordinates"]] if gtype == "Polygon" else geometry["coordinates"]
    xs = [p[0] for polygon in polygons for ring in polygon for p in ring]
    ys = [p[1] for polygon in polygons for ring in polygon for p in ring]
    return (min(xs), min(ys), max(xs), max(ys))
