"""NASA GIBS WMTS: satellite map layers for the app's map view.

Verified live: `GetCapabilities` on the EPSG:3857 endpoint lists layers
such as `MODIS_Terra_NDVI_8Day` and
`MODIS_Terra_CorrectedReflectance_TrueColor`, and a REST tile at
`/wmts/epsg3857/best/<layer>/default/<date>/GoogleMapsCompatible_Level9/<z>/<row>/<col>.jpg`
returned a 256x256 JPEG (tile z=6, row=27, col=43 was fetched; Bangladesh
at 88.6E is col 47 at that zoom - use `lat_lon_to_tile`).

Tile coordinates are `{z}/{row}/{col}` = `{z}/{y}/{x}` in XYZ terms. Each
layer has its own native format and maximum zoom (`Level9` here is the
true-colour layer's); read both from capabilities for other layers.
"""

from __future__ import annotations

import math
from datetime import date

from app.integrations.common.errors import IntegrationValidationError
from app.integrations.common.geo import validate_lat_lon
from app.integrations.common.http import ProviderHttp

PROVIDER = "NASA GIBS"
TRUE_COLOR_LAYER = "MODIS_Terra_CorrectedReflectance_TrueColor"
NDVI_8DAY_LAYER = "MODIS_Terra_NDVI_8Day"


def lat_lon_to_tile(latitude: float, longitude: float, zoom: int) -> tuple[int, int]:
    """Web-Mercator (XYZ) tile for a point. Returns (row/y, col/x)."""
    validate_lat_lon(latitude, longitude, provider=PROVIDER)
    if not 0 <= zoom <= 18:
        raise IntegrationValidationError("zoom must be 0-18", provider=PROVIDER)
    if abs(latitude) > 85.0511:
        raise IntegrationValidationError("latitude outside Web-Mercator range", provider=PROVIDER)
    n = 2**zoom
    x = int((longitude + 180.0) / 360.0 * n)
    lat_rad = math.radians(latitude)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return min(max(y, 0), n - 1), min(max(x, 0), n - 1)


class GibsClient:
    def __init__(self, *, base_url: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._http = http

    def tile_url(
        self,
        *,
        layer: str,
        day: date,
        zoom: int,
        row: int,
        col: int,
        tile_matrix_set: str = "GoogleMapsCompatible_Level9",
        extension: str = "jpg",
    ) -> str:
        """Pure URL builder - no network. Use this for map tile layers."""
        if extension not in ("jpg", "jpeg", "png"):
            raise IntegrationValidationError("extension must be jpg or png", provider=PROVIDER)
        if zoom < 0 or row < 0 or col < 0:
            raise IntegrationValidationError("zoom/row/col must be >= 0", provider=PROVIDER)
        return (
            f"{self._base}/wmts/epsg3857/best/{layer}/default/{day.isoformat()}/"
            f"{tile_matrix_set}/{zoom}/{row}/{col}.{extension}"
        )

    def tile_url_template(
        self,
        *,
        layer: str,
        day: date,
        tile_matrix_set: str = "GoogleMapsCompatible_Level9",
        extension: str = "jpg",
    ) -> str:
        """XYZ template (`{z}/{y}/{x}`) for flutter_map / Leaflet layers."""
        return (
            f"{self._base}/wmts/epsg3857/best/{layer}/default/{day.isoformat()}/"
            f"{tile_matrix_set}/{{z}}/{{y}}/{{x}}.{extension}"
        )

    async def fetch_tile(
        self,
        *,
        layer: str,
        day: date,
        zoom: int,
        row: int,
        col: int,
        tile_matrix_set: str = "GoogleMapsCompatible_Level9",
        extension: str = "jpg",
    ) -> bytes:
        url = self.tile_url(
            layer=layer,
            day=day,
            zoom=zoom,
            row=row,
            col=col,
            tile_matrix_set=tile_matrix_set,
            extension=extension,
        )
        result = await self._http.get(url, dataset=f"GIBS {layer}")
        return result.content

    async def fetch_capabilities_xml(self) -> str:
        result = await self._http.get(
            f"{self._base}/wmts/epsg3857/best/wmts.cgi",
            dataset="GIBS capabilities",
            params={"SERVICE": "WMTS", "request": "GetCapabilities"},
        )
        return result.text
