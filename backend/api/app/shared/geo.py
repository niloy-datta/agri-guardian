"""Geometry helpers.

Field boundaries are real polygons in EPSG:4326, never a bare lat/lng pair.
Structural validation happens here (cheap, before touching the DB);
topological validation (self-intersection) is delegated to PostGIS
`ST_IsValid` at write time, which is authoritative.
"""

import json
from typing import Any

MIN_RING_POINTS = 4  # a closed triangle: 3 distinct corners + repeated first point
MAX_RING_POINTS = 10_000
LON_MIN, LON_MAX = -180.0, 180.0
LAT_MIN, LAT_MAX = -90.0, 90.0


class InvalidGeometryError(ValueError):
    """Raised when a submitted GeoJSON geometry is structurally unusable."""


def validate_polygon_geojson(geometry: Any) -> dict:
    """Validates a GeoJSON Polygon and returns it normalized.

    Checks the envelope only: correct type, at least one linear ring, rings
    closed, enough points, coordinates in range. Does not check for
    self-intersection - PostGIS does that with full topological rigor.
    """
    if not isinstance(geometry, dict):
        raise InvalidGeometryError("Geometry must be a GeoJSON object")

    geom_type = geometry.get("type")
    if geom_type != "Polygon":
        raise InvalidGeometryError(f"Geometry type must be 'Polygon', got {geom_type!r}")

    rings = geometry.get("coordinates")
    if not isinstance(rings, list) or not rings:
        raise InvalidGeometryError("Polygon must have at least one linear ring")

    normalized_rings: list[list[list[float]]] = []
    for ring_index, ring in enumerate(rings):
        normalized_rings.append(_validate_ring(ring, ring_index))

    return {"type": "Polygon", "coordinates": normalized_rings}


def _validate_ring(ring: Any, ring_index: int) -> list[list[float]]:
    if not isinstance(ring, list):
        raise InvalidGeometryError(f"Ring {ring_index} must be a list of positions")

    if len(ring) < MIN_RING_POINTS:
        raise InvalidGeometryError(
            f"Ring {ring_index} needs at least {MIN_RING_POINTS} positions "
            f"(closed ring), got {len(ring)}"
        )

    if len(ring) > MAX_RING_POINTS:
        raise InvalidGeometryError(
            f"Ring {ring_index} exceeds {MAX_RING_POINTS} positions; simplify before upload"
        )

    normalized: list[list[float]] = []
    for position_index, position in enumerate(ring):
        normalized.append(_validate_position(position, ring_index, position_index))

    if normalized[0] != normalized[-1]:
        raise InvalidGeometryError(
            f"Ring {ring_index} is not closed: first and last position must be identical"
        )

    return normalized


def _validate_position(position: Any, ring_index: int, position_index: int) -> list[float]:
    where = f"ring {ring_index} position {position_index}"

    if not isinstance(position, (list, tuple)) or len(position) < 2:
        raise InvalidGeometryError(f"{where} must be [longitude, latitude]")

    lon, lat = position[0], position[1]
    if isinstance(lon, bool) or isinstance(lat, bool):
        raise InvalidGeometryError(f"{where} coordinates must be numbers")
    if not isinstance(lon, (int, float)) or not isinstance(lat, (int, float)):
        raise InvalidGeometryError(f"{where} coordinates must be numbers")

    if not LON_MIN <= lon <= LON_MAX:
        raise InvalidGeometryError(f"{where} longitude {lon} out of range [-180, 180]")
    if not LAT_MIN <= lat <= LAT_MAX:
        raise InvalidGeometryError(f"{where} latitude {lat} out of range [-90, 90]")

    return [float(lon), float(lat)]


def polygon_to_geojson_string(geometry: dict) -> str:
    """Serializes a validated polygon for `ST_GeomFromGeoJSON`."""
    return json.dumps(geometry, separators=(",", ":"))
