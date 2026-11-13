"""OpenTopography Global DEM API plus elevation/slope summary.

Verified live: `GET /API/globaldem?demtype=COP30&south&north&west&east&outputFormat=GTiff`
without a key returns HTTP 401 ("API Key required"), and a malformed key
returns 401 ("Not a valid format API Key"). A real key is free at
opentopography.org. Because no key was available, **the successful DEM
download is unverified here**; the ESRI ASCII grid (`outputFormat=AAIGrid`)
parser and the slope maths are covered by tests on synthetic grids whose
correct answer is known analytically.

We request `AAIGrid` (plain text: `ncols nrows xllcorner yllcorner cellsize
NODATA_value` then rows north-to-south) so no GDAL dependency is needed.

`summarize_dem` reports elevation and slope statistics only. It does not
claim flood or drainage outcomes - low relief is context, not a verdict.
Slope uses Horn's method on a cell size converted from degrees to metres at
the grid's latitude.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import validate_bbox
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "OpenTopography"
DEM_TYPES = frozenset(
    {"SRTMGL3", "SRTMGL1", "SRTMGL1_E", "AW3D30", "AW3D30_E", "SRTM15Plus", "NASADEM",
     "COP30", "COP90", "EU_DTM", "GEDI_L3", "GEBCO_2024", "GEBCO_2024_TID"}
)  # fmt: skip
_MAX_AREA_DEG2 = 0.25  # keep requests field/district sized
_M_PER_DEG_LAT = 110_574.0
_M_PER_DEG_LON_EQUATOR = 111_320.0


@dataclass(frozen=True, slots=True)
class DemGrid:
    elevation: np.ndarray = field(repr=False)
    """2-D float array, row 0 = north edge; NODATA cells are NaN."""
    xll: float
    yll: float
    cellsize_deg: float

    @property
    def center_latitude(self) -> float:
        return self.yll + self.cellsize_deg * self.elevation.shape[0] / 2.0


@dataclass(frozen=True, slots=True)
class TerrainSummary:
    elevation_min_m: float
    elevation_mean_m: float
    elevation_max_m: float
    relief_m: float
    slope_mean_deg: float
    slope_max_deg: float
    flat_fraction: float
    """Fraction of cells with slope below `flat_threshold_deg`."""
    flat_threshold_deg: float
    valid_cells: int
    total_cells: int


@dataclass(frozen=True, slots=True)
class DemResult:
    grid: DemGrid
    summary: TerrainSummary
    provenance: Provenance


def parse_aaigrid(text: str) -> DemGrid:
    lines = text.strip().splitlines()
    header: dict[str, float] = {}
    idx = 0
    while idx < len(lines):
        parts = lines[idx].split()
        if len(parts) == 2 and parts[0].lower() in {
            "ncols", "nrows", "xllcorner", "yllcorner", "xllcenter", "yllcenter",
            "cellsize", "dx", "dy", "nodata_value",
        }:  # fmt: skip
            header[parts[0].lower()] = float(parts[1])
            idx += 1
        else:
            break
    try:
        ncols = int(header["ncols"])
        nrows = int(header["nrows"])
        cellsize = header["cellsize"] if "cellsize" in header else header["dx"]
        xll = header["xllcorner"] if "xllcorner" in header else header["xllcenter"] - cellsize / 2
        yll = header["yllcorner"] if "yllcorner" in header else header["yllcenter"] - cellsize / 2
    except KeyError as exc:
        raise IntegrationResponseError(
            f"AAIGrid header missing {exc}", provider=PROVIDER
        ) from exc
    nodata = header.get("nodata_value")
    values = np.array(" ".join(lines[idx:]).split(), dtype=float)
    if values.size != ncols * nrows:
        raise IntegrationResponseError(
            f"AAIGrid has {values.size} values, expected {ncols * nrows}", provider=PROVIDER
        )
    grid = values.reshape(nrows, ncols)
    if nodata is not None:
        grid = np.where(grid == nodata, np.nan, grid)
    return DemGrid(elevation=grid, xll=xll, yll=yll, cellsize_deg=cellsize)


def slope_degrees(grid: DemGrid) -> np.ndarray:
    """Horn slope in degrees; edge and NODATA-adjacent cells are NaN."""
    z = grid.elevation
    lat = math.radians(grid.center_latitude)
    dx = grid.cellsize_deg * _M_PER_DEG_LON_EQUATOR * math.cos(lat)
    dy = grid.cellsize_deg * _M_PER_DEG_LAT
    slope = np.full_like(z, np.nan)
    if z.shape[0] < 3 or z.shape[1] < 3:
        return slope
    a, b, c = z[:-2, :-2], z[:-2, 1:-1], z[:-2, 2:]
    d, f = z[1:-1, :-2], z[1:-1, 2:]
    g, h, i = z[2:, :-2], z[2:, 1:-1], z[2:, 2:]
    dzdx = ((c + 2 * f + i) - (a + 2 * d + g)) / (8 * dx)
    dzdy = ((g + 2 * h + i) - (a + 2 * b + c)) / (8 * dy)
    slope[1:-1, 1:-1] = np.degrees(np.arctan(np.hypot(dzdx, dzdy)))
    return slope


def summarize_dem(grid: DemGrid, *, flat_threshold_deg: float = 2.0) -> TerrainSummary:
    z = grid.elevation
    valid = z[~np.isnan(z)]
    if valid.size == 0:
        raise IntegrationResponseError("DEM contains no valid cells", provider=PROVIDER)
    slope = slope_degrees(grid)
    slope_valid = slope[~np.isnan(slope)]
    if slope_valid.size == 0:
        raise IntegrationResponseError(
            "DEM too small to compute slope (need at least 3x3 valid cells)", provider=PROVIDER
        )
    return TerrainSummary(
        elevation_min_m=float(valid.min()),
        elevation_mean_m=float(valid.mean()),
        elevation_max_m=float(valid.max()),
        relief_m=float(valid.max() - valid.min()),
        slope_mean_deg=float(slope_valid.mean()),
        slope_max_deg=float(slope_valid.max()),
        flat_fraction=float((slope_valid < flat_threshold_deg).mean()),
        flat_threshold_deg=flat_threshold_deg,
        valid_cells=int(valid.size),
        total_cells=int(z.size),
    )


class OpenTopographyClient:
    def __init__(self, *, base_url: str, api_key: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._key = api_key
        self._http = http

    async def fetch_dem(
        self,
        *,
        bbox: tuple[float, float, float, float],
        demtype: str = "COP30",
        flat_threshold_deg: float = 2.0,
    ) -> DemResult:
        if not self._key:
            raise IntegrationCredentialsMissingError(
                "opentopography_api_key is not configured", provider=PROVIDER
            )
        west, south, east, north = validate_bbox(*bbox, provider=PROVIDER)
        if demtype not in DEM_TYPES:
            raise IntegrationValidationError(
                f"demtype must be one of {sorted(DEM_TYPES)}", provider=PROVIDER
            )
        if (east - west) * (north - south) > _MAX_AREA_DEG2:
            raise IntegrationValidationError(
                f"bbox larger than {_MAX_AREA_DEG2} square degrees; request a smaller area",
                provider=PROVIDER,
            )
        result = await self._http.get(
            f"{self._base}/globaldem",
            dataset=f"OpenTopography {demtype}",
            params={
                "demtype": demtype,
                "south": south,
                "north": north,
                "west": west,
                "east": east,
                "outputFormat": "AAIGrid",
                "API_Key": self._key,
            },
        )
        text = result.text
        if not text.lstrip().lower().startswith("ncols"):
            raise IntegrationResponseError(
                f"OpenTopography did not return an AAIGrid: {text[:200]!r}", provider=PROVIDER
            )
        grid = parse_aaigrid(text)
        return DemResult(
            grid=grid,
            summary=summarize_dem(grid, flat_threshold_deg=flat_threshold_deg),
            provenance=result.provenance,
        )
