"""Centralized application settings, loaded from environment variables.

Nothing in this module reads secrets from source-controlled files. All
values come from the environment (or `.env`, which is gitignored).
"""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/api - the directory containing pyproject.toml, alembic.ini, and
# this app/ package. Used to resolve NASA POWER cache/fixture paths so
# they never depend on the process's current working directory (which
# differs between `uvicorn` from backend/api, pytest, and the Docker
# entrypoint).
_BACKEND_API_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "local"
    app_name: str = "AgriGuardian"
    app_debug: bool = True
    api_v1_prefix: str = "/api/v1"

    database_url: str = "postgresql+asyncpg://agri_guardian:agri_guardian@localhost:5432/agri_guardian"
    database_url_sync: str = "postgresql+psycopg://agri_guardian:agri_guardian@localhost:5432/agri_guardian"

    redis_url: str = "redis://localhost:6379/0"

    supabase_url: str = ""
    supabase_jwt_secret: str = ""
    supabase_jwt_audience: str = "authenticated"
    auth_provider: str = "firebase"
    firebase_project_id: str = ""
    firebase_service_account_json: str = ""
    otp_hmac_secret: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from_email: str = ""

    storage_provider: str = "s3"
    storage_endpoint_url: str = ""
    storage_bucket: str = "agri-guardian-media"
    storage_access_key: str = ""
    storage_secret_key: str = ""
    storage_region: str = "auto"

    nasa_earthdata_token: str = ""
    copernicus_client_id: str = ""
    copernicus_client_secret: str = ""
    weather_provider_api_key: str = ""
    ai_inference_endpoint: str = ""
    ai_inference_api_key: str = ""

    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"

    # --- NASA POWER (Prediction Of Worldwide Energy Resources) ---
    # Open data API, no API key: https://power.larc.nasa.gov. This is a
    # different access path from NASA Earthdata (nasa_earthdata_token
    # above), which POWER's Daily Point endpoint does not require.
    nasa_power_base_url: str = "https://power.larc.nasa.gov"
    nasa_power_timeout_seconds: float = 30.0
    # Explicit and deterministic: true means the client and cache layer
    # must make zero network calls, ever, and fall back to committed
    # fixtures or fail clearly. Never inferred from "is there a token".
    nasa_power_offline: bool = False
    nasa_power_cache_dir: str = "cache/nasa_power"
    nasa_power_fixture_dir: str = "tests/fixtures/nasa_power"

    # --- Extended data-provider integrations (app/integrations/*) ---
    # Global kill switch: true means no integration client may touch the
    # network. Explicit, never inferred from missing credentials.
    integrations_offline: bool = False
    integrations_timeout_seconds: float = 30.0
    integrations_max_retries: int = 2

    # NASA Earthdata (AppEEARS login uses username/password; Harmony and
    # GES DISC use `nasa_earthdata_token` above).
    nasa_earthdata_username: str = ""
    nasa_earthdata_password: str = ""
    appeears_base_url: str = "https://appeears.earthdatacloud.nasa.gov/api"
    harmony_base_url: str = "https://harmony.earthdata.nasa.gov"
    cmr_base_url: str = "https://cmr.earthdata.nasa.gov/search"
    asf_base_url: str = "https://api.daac.asf.alaska.edu"
    eonet_base_url: str = "https://eonet.gsfc.nasa.gov/api/v3"
    gibs_base_url: str = "https://gibs.earthdata.nasa.gov"

    # Copernicus Data Space Ecosystem (CDSE). `copernicus_client_id` /
    # `copernicus_client_secret` above are an OAuth client created in the
    # CDSE dashboard; they authenticate Sentinel Hub and openEO.
    cdse_token_url: str = (
        "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"
    )
    cdse_stac_url: str = "https://catalogue.dataspace.copernicus.eu/stac"
    cdse_odata_url: str = "https://catalogue.dataspace.copernicus.eu/odata/v1"
    cdse_download_url: str = "https://download.dataspace.copernicus.eu/odata/v1"
    cdse_openeo_url: str = "https://openeo.dataspace.copernicus.eu/openeo/1.2"
    cdse_s3_endpoint: str = "https://eodata.dataspace.copernicus.eu"
    sentinel_hub_base_url: str = "https://sh.dataspace.copernicus.eu"

    earth_search_url: str = "https://earth-search.aws.element84.com/v1"
    planetary_computer_stac_url: str = "https://planetarycomputer.microsoft.com/api/stac/v1"
    planetary_computer_sas_url: str = "https://planetarycomputer.microsoft.com/api/sas/v1/sign"

    # Google Earth Engine REST. Needs a Cloud project with the Earth
    # Engine API enabled and a service-account key file (requires the
    # optional `google-auth` package) - see integrations/gee/client.py.
    gee_project: str = ""
    gee_service_account_file: str = ""
    gee_base_url: str = "https://earthengine.googleapis.com/v1"

    soilgrids_rest_url: str = "https://rest.isric.org/soilgrids/v2.0"
    soilgrids_wcs_url: str = "https://maps.isric.org/mapserv"
    wosis_graphql_url: str = "https://graphql.isric.org/wosis/graphql"

    # FAOSTAT's query API now requires a bearer token (verified: HTTP 401
    # "Missing Authorization Header" without one). The open bulk-download
    # files need no token and are the keyless path.
    faostat_api_url: str = "https://faostatservices.fao.org/api/v1"
    faostat_bulk_catalog_url: str = "https://bulks-faostat.fao.org/production/datasets_E.json"
    faostat_token: str = ""

    open_meteo_forecast_url: str = "https://api.open-meteo.com/v1/forecast"
    open_meteo_archive_url: str = "https://archive-api.open-meteo.com/v1/archive"
    open_meteo_flood_url: str = "https://flood-api.open-meteo.com/v1/flood"
    open_meteo_api_key: str = ""

    opentopography_api_key: str = ""
    opentopography_base_url: str = "https://portal.opentopography.org/API"

    @property
    def is_local(self) -> bool:
        return self.app_env == "local"

    def resolve_nasa_power_cache_dir(self) -> Path:
        """Resolves `nasa_power_cache_dir` against the backend/api root,
        not the process CWD, unless an absolute path was configured."""
        path = Path(self.nasa_power_cache_dir)
        return path if path.is_absolute() else _BACKEND_API_ROOT / path

    def resolve_nasa_power_fixture_dir(self) -> Path:
        path = Path(self.nasa_power_fixture_dir)
        return path if path.is_absolute() else _BACKEND_API_ROOT / path


@lru_cache
def get_settings() -> Settings:
    return Settings()
