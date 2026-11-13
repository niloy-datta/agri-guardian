"""Catalogue of the 30 data-provider integrations: what each is for, how it
authenticates, where it lives, and - honestly - how far it has been
verified.

`VERIFIED` means a real request to the live service was made while
writing the client and the parser matches what came back. `PARTIAL` means
the keyless part was verified but the authenticated part was not.
`UNVERIFIED` means the service needs credentials that were not available,
so the client is built from the provider's documentation and covered only
by tests against documented-shape fixtures. Nothing marked UNVERIFIED
should drive an advisory until `scripts/integration_smoke.py` has passed
against the real service with real credentials.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

from app.core.config import Settings


class Verification(StrEnum):
    VERIFIED = "verified"
    PARTIAL = "partial"
    UNVERIFIED = "unverified"


class Auth(StrEnum):
    NONE = "none"
    EARTHDATA_TOKEN = "earthdata_token"
    EARTHDATA_LOGIN = "earthdata_login"
    CDSE_OAUTH = "cdse_oauth"
    API_KEY = "api_key"
    GCP_SERVICE_ACCOUNT = "gcp_service_account"
    FAOSTAT_TOKEN = "faostat_token"


@dataclass(frozen=True, slots=True)
class IntegrationSpec:
    number: int
    name: str
    use_case: str
    priority: str
    auth: Auth
    module: str
    verification: Verification
    note: str = ""


def _s(
    number: int,
    name: str,
    use_case: str,
    priority: str,
    auth: Auth,
    module: str,
    verification: Verification,
    note: str = "",
) -> IntegrationSpec:
    return IntegrationSpec(number, name, use_case, priority, auth, module, verification, note)


V, P, U = Verification.VERIFIED, Verification.PARTIAL, Verification.UNVERIFIED

INTEGRATIONS: tuple[IntegrationSpec, ...] = (
    _s(1, "NASA POWER Daily API", "Historical rainfall, temperature", "P0", Auth.NONE,
       "app.integrations.nasa.client", V, "Pre-existing, audited planting-window evidence path."),
    _s(2, "NASA POWER Hourly API", "Hourly climate conditions", "P1", Auth.NONE,
       "app.integrations.nasa.power_extended", V),
    _s(3, "NASA POWER Monthly API", "Seasonal climate trends", "P1", Auth.NONE,
       "app.integrations.nasa.power_extended", V, "Key YYYY13 is the annual mean, split out."),
    _s(4, "NASA POWER Climatology API", "Long-term climate baselines", "P1", Auth.NONE,
       "app.integrations.nasa.power_extended", V),
    _s(5, "NASA POWER CMIP6 Projection API", "Future climate scenarios", "P1", Auth.NONE,
       "app.integrations.nasa.power_extended", P,
       "API responds, but returned only fill values (-999) for Bangladesh/N. India points; "
       "has_coverage=False. Do not use for BD advisories yet."),
    _s(6, "NASA Earthdata CMR API", "Discover NASA datasets", "P1", Auth.NONE,
       "app.integrations.nasa.discovery", V),
    _s(7, "NASA Harmony API", "Satellite data subsetting", "P1", Auth.EARTHDATA_TOKEN,
       "app.integrations.nasa.harmony", P, "Capabilities verified; data request needs a token."),
    _s(8, "NASA AppEEARS Area API", "Field polygon satellite data", "P0", Auth.EARTHDATA_LOGIN,
       "app.integrations.nasa.appeears", P, "Product/layer catalog verified; tasks need a login."),
    _s(9, "NASA AppEEARS Point API", "Location-based satellite data", "P1", Auth.EARTHDATA_LOGIN,
       "app.integrations.nasa.appeears", P, "Product/layer catalog verified; tasks need a login."),
    _s(10, "NASA GES DISC OPeNDAP", "GPM IMERG rainfall grids", "P1", Auth.EARTHDATA_TOKEN,
       "app.integrations.nasa.imerg_client", P,
       "Pre-existing. Metadata verified; no data parser by design until a token is available."),
    _s(11, "NASA GIBS WMTS API", "Satellite map layers", "P1", Auth.NONE,
       "app.integrations.nasa.gibs", V),
    _s(12, "NASA ASF Search API", "Sentinel-1 radar data", "P1", Auth.NONE,
       "app.integrations.nasa.discovery", V, "Discovery only; downloads need an Earthdata login."),
    _s(13, "NASA EONET API", "Natural hazard events", "P2", Auth.NONE,
       "app.integrations.nasa.discovery", V),
    _s(14, "Copernicus STAC API", "Sentinel imagery discovery", "P1", Auth.NONE,
       "app.integrations.stac.client", V, "Uses GET collection items; POST /search was a 502."),
    _s(15, "Copernicus OData API", "Sentinel product downloads", "P1", Auth.CDSE_OAUTH,
       "app.integrations.copernicus.cdse", P, "Search verified; download needs a token."),
    _s(16, "Sentinel Hub Processing API", "NDVI, vegetation maps", "P0", Auth.CDSE_OAUTH,
       "app.integrations.copernicus.sentinel_hub", U),
    _s(17, "Sentinel Hub Statistical API", "Field-level NDVI time series", "P0", Auth.CDSE_OAUTH,
       "app.integrations.copernicus.sentinel_hub", U),
    _s(18, "Sentinel Hub Catalog API", "Cloud-filtered image search", "P1", Auth.CDSE_OAUTH,
       "app.integrations.copernicus.sentinel_hub", U),
    _s(19, "Copernicus openEO API", "Satellite data processing", "P1", Auth.CDSE_OAUTH,
       "app.integrations.copernicus.cdse", P, "Collections verified; /result needs a token."),
    _s(20, "Copernicus S3 API", "Large satellite data access", "P2", Auth.API_KEY,
       "app.integrations.copernicus.cdse", U,
       "Locator only (S3Path -> bucket/key); no S3 SDK dependency, no download."),
    _s(21, "Earth Search STAC API", "Landsat and Sentinel imagery", "P1", Auth.NONE,
       "app.integrations.stac.client", V),
    _s(22, "Microsoft Planetary Computer API", "Global geospatial datasets", "P1", Auth.NONE,
       "app.integrations.stac.client", V, "SAS signing verified."),
    _s(23, "Google Earth Engine REST API", "Satellite analytics", "P1", Auth.GCP_SERVICE_ACCOUNT,
       "app.integrations.gee.client", U, "Needs a GCP project, key, and optional google-auth."),
    _s(24, "ISRIC SoilGrids WCS", "Soil pH, carbon, nitrogen, texture", "P0", Auth.NONE,
       "app.integrations.soil.soilgrids", V,
       "WCS verified for BD. REST point query returns null for BD points."),
    _s(25, "ISRIC WoSIS GraphQL API", "Soil profile observations", "P1", Auth.NONE,
       "app.integrations.soil.wosis", V),
    _s(26, "FAOSTAT API", "Crop yield, agricultural statistics", "P0", Auth.FAOSTAT_TOKEN,
       "app.integrations.fao.faostat", P,
       "Query API now requires auth (401). Keyless bulk-file path verified."),
    _s(27, "Open-Meteo Forecast API", "Weather, rainfall, irrigation planning", "P0", Auth.NONE,
       "app.integrations.weather.open_meteo", V),
    _s(28, "Open-Meteo Historical API", "Historical weather cross-check", "P1", Auth.NONE,
       "app.integrations.weather.open_meteo", V),
    _s(29, "Open-Meteo Flood API", "Flood and river-discharge risk", "P1", Auth.NONE,
       "app.integrations.weather.open_meteo", V),
    _s(30, "OpenTopography Global DEM API", "Elevation, slope and drainage context", "P0",
       Auth.API_KEY, "app.integrations.terrain.opentopography", U,
       "Needs a free API key; slope maths tested analytically."),
)  # fmt: skip


def is_configured(spec: IntegrationSpec, settings: Settings) -> bool:
    """Whether the credentials this integration needs are present."""
    match spec.auth:
        case Auth.NONE:
            return True
        case Auth.EARTHDATA_TOKEN:
            return bool(settings.nasa_earthdata_token)
        case Auth.EARTHDATA_LOGIN:
            return bool(settings.nasa_earthdata_username and settings.nasa_earthdata_password)
        case Auth.CDSE_OAUTH:
            return bool(settings.copernicus_client_id and settings.copernicus_client_secret)
        case Auth.GCP_SERVICE_ACCOUNT:
            return bool(settings.gee_project and settings.gee_service_account_file)
        case Auth.FAOSTAT_TOKEN:
            return True  # keyless bulk path exists; token only unlocks the query API
        case Auth.API_KEY:
            if spec.number == 30:
                return bool(settings.opentopography_api_key)
            return False  # CDSE S3 keys have no setting: locator needs none
    return False  # pragma: no cover
