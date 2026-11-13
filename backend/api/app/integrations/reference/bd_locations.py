"""Nationwide Bangladesh location intelligence (extends dataset #3).

Any point or field polygon in Bangladesh is resolved to its district and
division by point-in-polygon against geoBoundaries ADM2 (see
`scripts/build_bd_admin.py` for sources and licences). The Rajshahi
GeoNames point remains the *historical pilot* location only; nothing here
defaults to it.

Polygons are simplified (~4-decimal vertices). A point within a few
hundred metres of a district or national border can resolve to the
neighbour or fall outside; such results carry `near_boundary=True`.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

_DATA = Path(__file__).parent / "data" / "bd_districts.json"
_NEAR_BOUNDARY_KM = 0.5
_GAP_KM = 5.0

Ring = list[list[float]]
Polygons = list[list[Ring]]


@dataclass(frozen=True, slots=True)
class District:
    name: str
    division: str
    geonames_id: int
    centroid: tuple[float, float]
    """(lat, lon) from GeoNames."""
    polygons: Polygons
    bbox: tuple[float, float, float, float]


@dataclass(frozen=True, slots=True)
class LocationResolution:
    latitude: float
    longitude: float
    in_bangladesh: bool
    district: str | None
    division: str | None
    near_boundary: bool


class OutsideBangladeshError(ValueError):
    pass


def _bbox(polys: Polygons) -> tuple[float, float, float, float]:
    xs = [p[0] for poly in polys for ring in poly for p in ring]
    ys = [p[1] for poly in polys for ring in poly for p in ring]
    return min(xs), min(ys), max(xs), max(ys)


@lru_cache(maxsize=1)
def _load() -> tuple[Polygons, tuple[District, ...], dict[str, Any]]:
    raw = json.loads(_DATA.read_text(encoding="utf-8"))
    districts = tuple(
        District(
            name=d["name"],
            division=d["division"],
            geonames_id=d["geonames_id"],
            centroid=(d["centroid"][0], d["centroid"][1]),
            polygons=d["polygons"],
            bbox=_bbox(d["polygons"]),
        )
        for d in raw["districts"]
    )
    return raw["national_polygons"], districts, raw["sources"]


def districts() -> tuple[District, ...]:
    return _load()[1]


def divisions() -> list[str]:
    return sorted({d.division for d in districts()})


def sources() -> dict[str, str]:
    return dict(_load()[2])


def get_district(name: str) -> District:
    key = name.strip().lower()
    for d in districts():
        if d.name.lower() == key:
            return d
    raise KeyError(f"unknown district: {name!r}")


def _in_ring(x: float, y: float, ring: Ring) -> bool:
    inside = False
    j = len(ring) - 1
    for i in range(len(ring)):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def _in_polygons(x: float, y: float, polys: Polygons) -> bool:
    for poly in polys:
        if poly and _in_ring(x, y, poly[0]) and not any(_in_ring(x, y, h) for h in poly[1:]):
            return True
    return False


def _min_edge_km(lat: float, lon: float, polys: Polygons) -> float:
    kx = 111.32 * math.cos(math.radians(lat))
    ky = 110.57
    best = math.inf
    for poly in polys:
        for ring in poly:
            for (x1, y1), (x2, y2) in zip(ring, ring[1:], strict=False):
                ax, ay = (x1 - lon) * kx, (y1 - lat) * ky
                bx, by = (x2 - lon) * kx, (y2 - lat) * ky
                dx, dy = bx - ax, by - ay
                t = (
                    0.0
                    if dx == dy == 0
                    else max(0.0, min(1.0, -(ax * dx + ay * dy) / (dx * dx + dy * dy)))
                )
                best = min(best, math.hypot(ax + t * dx, ay + t * dy))
    return best


def resolve_point(latitude: float, longitude: float) -> LocationResolution:
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        raise ValueError("coordinates out of range")
    national, ds, _ = _load()
    in_bd = _in_polygons(longitude, latitude, national)
    for d in ds:
        w, s, e, n = d.bbox
        if (
            w <= longitude <= e
            and s <= latitude <= n
            and _in_polygons(longitude, latitude, d.polygons)
        ):
            near = _min_edge_km(latitude, longitude, d.polygons) < _NEAR_BOUNDARY_KM
            return LocationResolution(latitude, longitude, True, d.name, d.division, near)
    if in_bd:
        # Inside the national outline but in a gap between simplified ADM2
        # polygons (typically a wide river channel): take the nearest
        # district within _GAP_KM and flag the result as near a boundary.
        dist, best = min((_min_edge_km(latitude, longitude, d.polygons), d) for d in ds)
        if dist <= _GAP_KM:
            return LocationResolution(latitude, longitude, True, best.name, best.division, True)
        return LocationResolution(latitude, longitude, True, None, None, True)
    near = _min_edge_km(latitude, longitude, national) < _NEAR_BOUNDARY_KM
    return LocationResolution(latitude, longitude, False, None, None, near)


def polygon_centroid(ring: Ring) -> tuple[float, float]:
    """Area centroid (lat, lon) of a simple lon/lat ring."""
    a = cx = cy = 0.0
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1], strict=True):
        cross = x1 * y2 - x2 * y1
        a += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    if abs(a) < 1e-12:
        raise ValueError("degenerate polygon")
    return cy / (3 * a), cx / (3 * a)


def resolve_field(ring: Ring) -> LocationResolution:
    """Resolve a field boundary (lon/lat ring). Every vertex must lie in Bangladesh."""
    if len(ring) < 3:
        raise ValueError("a field polygon needs at least 3 vertices")
    for lon, lat in ring:
        if not resolve_point(lat, lon).in_bangladesh:
            raise OutsideBangladeshError(f"vertex ({lat}, {lon}) is outside Bangladesh")
    lat, lon = polygon_centroid(ring)
    return resolve_point(lat, lon)
