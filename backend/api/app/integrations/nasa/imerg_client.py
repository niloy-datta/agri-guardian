"""NASA GPM IMERG Final Run (GPM_3IMERGDF) acquisition client - Phase 4B.1.

**Status: acquisition-layer scaffold only. No real IMERG data has been
acquired through this module in this project as of Phase 4B.1** - see
`docs/references/gpm_imerg_cross_validation.md` for the full disclosure. This
module intentionally does NOT parse a successful response into
precipitation records: every fact this file encodes about the product
(filename pattern, grid layout, variable name, units, fill value) was
independently verified against live, unauthenticated GES DISC OPeNDAP
metadata endpoints (`.das`/`.dds`/directory listings) during the review,
but the actual data payload has never been retrieved or inspected,
because that requires a NASA Earthdata Login token this environment does
not have. Writing a parser for a byte layout nobody has ever seen here
would be exactly the kind of invented, unverified science this project's
rules forbid - so it is not written. `fetch_daily_precipitation_raw`
below is a complete, honest, testable unit on its own: it acquires
(or clearly fails to acquire) the raw authenticated NASA response.

Verified, sourced facts (all confirmed via live requests in this
review - see the review doc for the exact commands
and responses):

- Product: GPM IMERG Final Precipitation L3 1-day, 0.1x0.1 degree
  (short name `GPM_3IMERGDF`), version 07 (minor revision "V07B" in
  actual filenames). DOI 10.5067/GPM/IMERGDF/DAY/07.
- Granule filename pattern, confirmed via a live, unauthenticated
  directory listing at
  https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDF.07/<YYYY>/<MM>/contents.html:
  `3B-DAY.MS.MRG.3IMERG.<YYYYMMDD>-S000000-E235959.V07B.nc4`.
- Variable `precipitation`: units "mm/day", long_name "Daily mean
  precipitation rate (combined microwave-IR) estimate. Formerly
  precipitationCal.", `_FillValue -9999.90039` - confirmed via a live,
  unauthenticated `.das` metadata request. This fill value is NOT the
  same as NASA POWER's `-999.0` - never assume the two products share a
  sentinel.
- Grid: 0.1 degree cells, `lon` dimension size 3600 (360/0.1), `lat`
  dimension size 1800 (180/0.1) - confirmed via a live, unauthenticated
  `.dds` metadata request.
- Real data access (an actual `.ascii` data-slice request, not just
  metadata) returns an HTTP 302 redirect to
  `urs.earthdata.nasa.gov/oauth/authorize/...` - confirmed live in this
  session. A separate raw OPeNDAP `.dap.nc4` request returned HTTP 401
  "HTTP Basic: Access denied." Both confirm the same fact from two
  different code paths: **actual precipitation values require a NASA
  Earthdata Login token with the "NASA GES DISC DATA ARCHIVE" and
  "Hyrax in the Cloud" applications authorized on that account** -
  metadata-only endpoints (`.das`, `.dds`, directory listings) do not.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date

import httpx

IMERG_PRODUCT_SHORT_NAME = "GPM_3IMERGDF"
IMERG_PRODUCT_VERSION = "07"
IMERG_PRODUCT_FILENAME_VERSION = "V07B"
"""The exact minor-revision string that appears in real granule
filenames and the `NC_GLOBAL` attributes - confirmed live, distinct from
the catalog-level version string "07" used in URLs/DOIs."""
IMERG_PRODUCT_DOI = "10.5067/GPM/IMERGDF/DAY/07"
IMERG_VARIABLE_NAME = "precipitation"
IMERG_UNITS = "mm/day"
"""Already a daily mean rate for a 1-day product - equivalent to that
day's accumulation. Do not multiply or divide by 24: this differs from a
sub-daily (e.g. half-hourly) IMERG product, which reports an
instantaneous rate that genuinely needs aggregation (see Task 12/13 in
the Phase 4B.1 brief; this project has not implemented sub-daily
aggregation because the Final daily product already does not need it)."""
IMERG_FILL_VALUE = -9999.90039
IMERG_GRID_RESOLUTION_DEG = 0.1
IMERG_LON_DIM = 3600
IMERG_LAT_DIM = 1800

_LAT_MIN, _LAT_MAX = -90.0, 90.0
_LON_MIN, _LON_MAX = -180.0, 180.0
_EARTH_RADIUS_KM = 6371.0088


class GpmImergError(Exception):
    """Base class for every error this client raises."""


class GpmImergValidationError(GpmImergError):
    """The request itself was invalid - raised before any network call."""


class GpmImergCredentialsMissingError(GpmImergError):
    """No Earthdata token was supplied. Raised before any network call is
    made - this client never attempts an unauthenticated data request
    and lets it fail with a confusing generic error."""


class GpmImergAuthenticationError(GpmImergError):
    """NASA responded with an authentication challenge (401, or a 302
    redirect to `urs.earthdata.nasa.gov`) even though a token was
    supplied - e.g. an expired token, or an Earthdata account that has
    not authorized the required applications. Never silently followed as
    if it were a successful response."""


class GpmImergRequestError(GpmImergError):
    """The HTTP request failed, or NASA returned an unexpected non-200,
    non-authentication status."""


@dataclass(frozen=True, slots=True)
class GpmImergGridCell:
    """Where a requested coordinate actually lands on IMERG's 0.1 degree
    grid - Task 6's "Same Location Contract": this project never pretends
    a grid-cell center is the same point as the requested coordinate."""

    requested_latitude: float
    requested_longitude: float
    longitude_index: int
    latitude_index: int
    grid_cell_longitude: float
    """The grid cell's own center longitude - not the requested value."""
    grid_cell_latitude: float
    grid_resolution_deg: float
    spatial_offset_km: float
    """Great-circle distance between the requested coordinate and the
    grid cell center actually selected."""


def resolve_grid_cell(*, latitude: float, longitude: float) -> GpmImergGridCell:
    """Pure, deterministic mapping from a coordinate to IMERG's 0.1 degree
    grid indices and the resulting cell-center coordinate, using the
    grid layout confirmed live against a real GES DISC `.dds` response
    (`lon` size 3600 spanning -180..180, `lat` size 1800 spanning
    -90..90). Never contacts the network."""
    if not _LAT_MIN <= latitude <= _LAT_MAX:
        raise GpmImergValidationError(f"latitude {latitude} out of range [{_LAT_MIN}, {_LAT_MAX}]")
    if not _LON_MIN <= longitude <= _LON_MAX:
        raise GpmImergValidationError(f"longitude {longitude} out of range [{_LON_MIN}, {_LON_MAX}]")

    lon_index = round((longitude - (-180.0)) / IMERG_GRID_RESOLUTION_DEG)
    lat_index = round((latitude - (-90.0)) / IMERG_GRID_RESOLUTION_DEG)
    lon_index = min(max(lon_index, 0), IMERG_LON_DIM - 1)
    lat_index = min(max(lat_index, 0), IMERG_LAT_DIM - 1)

    grid_lon = -180.0 + lon_index * IMERG_GRID_RESOLUTION_DEG
    grid_lat = -90.0 + lat_index * IMERG_GRID_RESOLUTION_DEG

    offset_km = _haversine_km(
        lat1=latitude, lon1=longitude, lat2=grid_lat, lon2=grid_lon
    )

    return GpmImergGridCell(
        requested_latitude=latitude,
        requested_longitude=longitude,
        longitude_index=lon_index,
        latitude_index=lat_index,
        grid_cell_longitude=grid_lon,
        grid_cell_latitude=grid_lat,
        grid_resolution_deg=IMERG_GRID_RESOLUTION_DEG,
        spatial_offset_km=offset_km,
    )


def _haversine_km(*, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def build_daily_granule_filename(day: date) -> str:
    """The exact real filename pattern, confirmed live against GES DISC's
    own directory listing for `GPM_3IMERGDF.07` (see module docstring)."""
    day_str = day.strftime("%Y%m%d")
    return f"3B-DAY.MS.MRG.3IMERG.{day_str}-S000000-E235959.{IMERG_PRODUCT_FILENAME_VERSION}.nc4"


def build_daily_granule_opendap_url(*, base_url: str, day: date) -> str:
    """The exact real OPeNDAP path for one day's granule, confirmed live
    (`.das`/`.dds`/directory-listing all resolved at this path)."""
    filename = build_daily_granule_filename(day)
    return (
        f"{base_url.rstrip('/')}/opendap/GPM_L3/{IMERG_PRODUCT_SHORT_NAME}.{IMERG_PRODUCT_VERSION}/"
        f"{day.year:04d}/{day.month:02d}/{filename}"
    )


def build_daily_point_ascii_request_url(*, base_url: str, day: date, grid_cell: GpmImergGridCell) -> str:
    """The exact real OPeNDAP ASCII data-slice URL for one day/coordinate
    - constrains the request to a single `[time][lon][lat]` triple rather
    than downloading the full 3600x1800 daily grid. This exact
    constraint-expression syntax was confirmed live to route correctly
    (it produced an Earthdata Login redirect, not a 404 or a syntax
    error) against the real GES DISC OPeNDAP server."""
    granule_url = build_daily_granule_opendap_url(base_url=base_url, day=day)
    return (
        f"{granule_url}.ascii?{IMERG_VARIABLE_NAME}"
        f"[0][{grid_cell.longitude_index}][{grid_cell.latitude_index}]"
    )


class GpmImergClient:
    """Acquisition-only client: authenticates and requests one day's
    precipitation value for one coordinate, and returns the raw NASA
    response. Does not parse the response body - see the module
    docstring for why. Never called from Flutter (external Earth-observation
    access is backend-only; see `CONTRIBUTING.md`)."""

    def __init__(
        self,
        *,
        earthdata_token: str,
        base_url: str = "https://gpm1.gesdisc.eosdis.nasa.gov",
        timeout_seconds: float = 30.0,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._earthdata_token = earthdata_token
        self._base_url = base_url.rstrip("/")
        self._timeout_seconds = timeout_seconds
        self._owns_client = http_client is None
        self._client = http_client or httpx.AsyncClient()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def __aenter__(self) -> GpmImergClient:
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self.aclose()

    async def fetch_daily_precipitation_raw(
        self, *, latitude: float, longitude: float, day: date
    ) -> httpx.Response:
        """Acquires the raw NASA response for one day/coordinate.

        Raises `GpmImergValidationError` for a request this client can
        reject without touching the network, `GpmImergCredentialsMissingError`
        if no Earthdata token was configured (checked before any network
        call - this method makes zero requests in that case),
        `GpmImergAuthenticationError` if NASA still challenges
        authentication despite a token being sent, and
        `GpmImergRequestError` for any other request failure.

        Returns the raw `httpx.Response` on HTTP 200 - parsing that body
        into a precipitation value is explicitly out of scope for this
        phase (see module docstring).
        """
        grid_cell = resolve_grid_cell(latitude=latitude, longitude=longitude)

        if not self._earthdata_token:
            raise GpmImergCredentialsMissingError(
                "No NASA Earthdata token configured (Settings.nasa_earthdata_token "
                "is empty). Real GPM IMERG data requires a NASA Earthdata Login "
                "account with the 'NASA GES DISC DATA ARCHIVE' and 'Hyrax in the "
                "Cloud' applications authorized on that account, and a bearer "
                "token or .netrc-based login built from it. See "
                "docs/references/gpm_imerg_cross_validation.md for the exact "
                "verification this project has already done."
            )

        request_url = build_daily_point_ascii_request_url(
            base_url=self._base_url, day=day, grid_cell=grid_cell
        )

        try:
            response = await self._client.get(
                request_url,
                headers={"Authorization": f"Bearer {self._earthdata_token}"},
                timeout=self._timeout_seconds,
                follow_redirects=False,
            )
        except httpx.HTTPError as exc:
            raise GpmImergRequestError(f"GPM IMERG request failed: {exc}") from exc

        if response.status_code in (401, 403):
            raise GpmImergAuthenticationError(
                f"NASA GES DISC rejected the request with HTTP {response.status_code} "
                "despite a configured Earthdata token - the token may be expired, "
                "or the Earthdata account may not have the 'NASA GES DISC DATA "
                "ARCHIVE' and 'Hyrax in the Cloud' applications authorized."
            )
        if response.status_code in (301, 302, 303, 307, 308):
            location = response.headers.get("location", "")
            if "urs.earthdata.nasa.gov" in location:
                raise GpmImergAuthenticationError(
                    "NASA GES DISC redirected this request to the Earthdata "
                    f"Login OAuth flow ({location[:200]}) despite a configured "
                    "token - the token is not being accepted for this resource. "
                    "This redirect is never followed automatically: silently "
                    "following it would risk treating an HTML login page as if "
                    "it were real precipitation data."
                )
            raise GpmImergRequestError(
                f"GPM IMERG request was redirected to an unexpected location: {location}"
            )
        if response.status_code != httpx.codes.OK:
            raise GpmImergRequestError(
                f"GPM IMERG request returned HTTP {response.status_code} for "
                f"{request_url}: {response.text[:500]}"
            )

        return response
