"""FAO GAEZ v5 crop suitability (dataset #6) - real downloadable rasters.

Source (verified live 2026-11-13): FAO's public bucket
`https://storage.googleapis.com/fao-gismgr-gaez-v5-data/DATA/GAEZ-V5/`,
the store behind the GAEZ v5 Data Portal (https://data.apps.fao.org/gaez/).
Licence: CC BY 4.0 + FAO database terms - cite "FAO & IIASA, GAEZ v5".

Mapset used: `RES05-SXX` = crop suitability index, 5 arc-minute (~9 km
at Bangladesh's latitude) global GeoTIFF, int16, nodata -9, LZW, 256x256
tiles, WGS 84 (verified from the file's own tags). File name pattern:
`GAEZ-V5.RES05-SXX.<PERIOD>.<CLIM>.<SSP>.<CROP>.<WSIM>.tif`, with
dimension members taken from the bucket's DIMENSION/*.csv files:
  PERIOD HP0120 = 2001-2020 (historical, AgERA5 climate, SSP HIST)
  WSIM   HRLM = rain-fed, high input; HILM = irrigated, high input;
         LRLM / LILM = the low-input equivalents.

What is NOT done here: no threshold turns the index into a "suitable" /
"not suitable" class, because the v5 class boundaries were not verified
in this project. Callers compare raw indices (crop vs crop, rain-fed vs
irrigated) at the same pixel, and treat 0 as "no suitability".

Each ~3-4 MB global file is downloaded once and cached; only the one tile
containing the point is decoded (pure-Python LZW, so no imagecodecs).
"""

from __future__ import annotations

import io
import struct
import time
from dataclasses import dataclass
from pathlib import Path

import tifffile

from app.integrations.common.errors import IntegrationResponseError, IntegrationValidationError
from app.integrations.common.geo import validate_lat_lon
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "FAO GAEZ v5"
BASE_URL = "https://storage.googleapis.com/fao-gismgr-gaez-v5-data/DATA/GAEZ-V5"
NODATA = -9
_CACHE_MAX_AGE_SECONDS = 30 * 24 * 3600

# GAEZ v5 CROP-RES05 codes for the crops in the BAMIS calendars. Lentil and
# jute have no GAEZ v5 RES05 crop; rapeseed is the closest oilseed to mustard
# (Brassica) and is labelled as a proxy, never as mustard itself.
CROP_CODES: dict[str, tuple[str, str]] = {
    "aman_rice": ("RCW", "Wetland rice"),
    "boro_rice": ("RCW", "Wetland rice"),
    "aus_rice": ("RCW", "Wetland rice"),
    "wheat": ("WHE", "Wheat"),
    "maize": ("MZE", "Maize"),
    "mustard": ("RSD", "Rapeseed (proxy for mustard)"),
}
WATER_SUPPLY = {"rainfed_high": "HRLM", "irrigated_high": "HILM",
                "rainfed_low": "LRLM", "irrigated_low": "LILM"}  # fmt: skip


@dataclass(frozen=True, slots=True)
class GaezSuitability:
    crop: str
    gaez_crop: str
    gaez_caption: str
    water_supply: str
    period: str
    index: int | None
    """Raw SXX suitability index; None when the pixel is nodata (-9)."""
    pixel_size_deg: float
    source_url: str
    provenance: Provenance | None


def layer_url(gaez_crop: str, wsim: str, period: str = "HP0120") -> str:
    clim, ssp = ("AGERA5", "HIST") if period.startswith("HP") else ("ENSEMBLE", "SSP370")
    name = f"GAEZ-V5.RES05-SXX.{period}.{clim}.{ssp}.{gaez_crop}.{wsim}.tif"
    return f"{BASE_URL}/MAPSET/RES05-SXX/{name}"


def lzw_decode(data: bytes) -> bytes:
    """TIFF-flavoured LZW (MSB-first, early change)."""
    table = [bytes([i]) for i in range(256)] + [b"", b""]
    out = bytearray()
    bits = 9
    buf = nbits = 0
    prev: bytes | None = None
    for byte in data:
        buf = (buf << 8) | byte
        nbits += 8
        while nbits >= bits:
            nbits -= bits
            code = (buf >> nbits) & ((1 << bits) - 1)
            if code == 256:  # clear
                table = table[:258]
                bits, prev = 9, None
                continue
            if code == 257:  # end of information
                return bytes(out)
            if code < len(table):
                entry = table[code]
                if prev is not None:
                    table.append(prev + entry[:1])
            elif prev is not None and code == len(table):
                entry = prev + prev[:1]
                table.append(entry)
            else:
                raise ValueError(f"bad LZW code {code}")
            out += entry
            prev = entry
            if len(table) + 1 >= (1 << bits) and bits < 12:
                bits += 1
    return bytes(out)


def read_pixel(tif_bytes: bytes, latitude: float, longitude: float) -> tuple[int | None, float]:
    """Value of the pixel containing (lat, lon) and the pixel size in degrees."""
    with tifffile.TiffFile(io.BytesIO(tif_bytes)) as tif:
        page = tif.pages[0]
        if not isinstance(page, tifffile.TiffPage):
            raise IntegrationResponseError("unexpected GAEZ TIFF layout", provider=PROVIDER)
        if not page.is_tiled or page.compression != 5 or page.predictor != 1:
            raise IntegrationResponseError("unexpected GAEZ TIFF layout", provider=PROVIDER)
        sx, sy, _ = page.tags[33550].value
        _, _, _, x0, y0, _ = page.tags[33922].value
        height, width = page.shape
        row, col = int((y0 - latitude) / sy), int((longitude - x0) / sx)
        if not (0 <= row < height and 0 <= col < width):
            return None, sx
        tw, tl = page.tilewidth, page.tilelength
        tiles_across = -(-width // tw)
        tile = (row // tl) * tiles_across + col // tw
        offset, count = page.dataoffsets[tile], page.databytecounts[tile]
    raw = lzw_decode(tif_bytes[offset : offset + count])
    idx = (row % tl) * tw + (col % tw)
    (value,) = struct.unpack_from("<h", raw, idx * 2)
    return (None if value == NODATA else value), sx


class GaezClient:
    def __init__(self, *, http: ProviderHttp, cache_dir: Path | None = None) -> None:
        self._http = http
        self._cache_dir = cache_dir

    async def _fetch(self, url: str) -> tuple[bytes, Provenance | None]:
        cached = self._cache_dir / url.rsplit("/", 1)[-1] if self._cache_dir else None
        if (
            cached
            and cached.exists()
            and time.time() - cached.stat().st_mtime < _CACHE_MAX_AGE_SECONDS
        ):
            return cached.read_bytes(), None
        result = await self._http.get(url, dataset="GAEZ v5 RES05-SXX")
        content = result.content
        if content[:4] not in (b"II*\x00", b"MM\x00*", b"II+\x00", b"MM\x00+"):  # TIFF / BigTIFF
            raise IntegrationResponseError(f"not a GeoTIFF: {url}", provider=PROVIDER)
        if cached:
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(content)
        return content, result.provenance

    async def suitability(
        self, *, crop: str, latitude: float, longitude: float,
        water_supply: str = "rainfed_high", period: str = "HP0120",
    ) -> GaezSuitability:  # fmt: skip
        validate_lat_lon(latitude, longitude, provider=PROVIDER)
        if crop not in CROP_CODES:
            raise IntegrationValidationError(
                f"GAEZ v5 has no RES05 crop for {crop!r}", provider=PROVIDER
            )
        if water_supply not in WATER_SUPPLY:
            raise IntegrationValidationError(
                f"unknown water_supply {water_supply!r}", provider=PROVIDER
            )
        code, caption = CROP_CODES[crop]
        url = layer_url(code, WATER_SUPPLY[water_supply], period)
        content, prov = await self._fetch(url)
        value, size = read_pixel(content, latitude, longitude)
        return GaezSuitability(crop, code, caption, water_supply, period, value, size, url, prov)
