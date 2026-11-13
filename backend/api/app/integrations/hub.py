"""Wires every integration client from `Settings`, sharing one HTTP pool.

Application code asks the hub for a client instead of constructing one, so
timeouts, retries, offline mode and credentials are configured in exactly
one place. Clients are built lazily; the hub owns (and closes) the shared
`httpx.AsyncClient` unless one is injected (tests).
"""

from __future__ import annotations

from functools import cached_property
from pathlib import Path

import httpx

from app.core.config import Settings, get_settings
from app.integrations.common.http import ProviderHttp
from app.integrations.common.oauth import ClientCredentialsTokenSource
from app.integrations.copernicus.cdse import CdseClient, CdseS3Locator
from app.integrations.copernicus.sentinel_hub import SentinelHubClient
from app.integrations.fao.faostat import FaostatClient
from app.integrations.fao.gaez import GaezClient
from app.integrations.gee.client import EarthEngineClient, ServiceAccountTokenSource
from app.integrations.nasa.appeears import AppeearsClient
from app.integrations.nasa.discovery import AsfClient, CmrClient, EonetClient
from app.integrations.nasa.gibs import GibsClient
from app.integrations.nasa.harmony import HarmonyClient
from app.integrations.nasa.power_extended import NasaPowerExtendedClient
from app.integrations.soil.soilgrids import SoilGridsClient
from app.integrations.soil.wosis import WosisClient
from app.integrations.stac.client import CdseStacClient, PlanetaryComputerStacClient, StacClient
from app.integrations.terrain.opentopography import OpenTopographyClient
from app.integrations.weather.open_meteo import OpenMeteoClient


class IntegrationHub:
    def __init__(
        self,
        settings: Settings | None = None,
        *,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._client = http_client or httpx.AsyncClient()
        self._owns_client = http_client is None

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    def _http(self, provider: str) -> ProviderHttp:
        s = self._settings
        return ProviderHttp(
            provider=provider,
            timeout_seconds=s.integrations_timeout_seconds,
            max_retries=s.integrations_max_retries,
            offline=s.integrations_offline,
            http_client=self._client,
        )

    @cached_property
    def _cdse_tokens(self) -> ClientCredentialsTokenSource | None:
        s = self._settings
        if not (s.copernicus_client_id and s.copernicus_client_secret):
            return None
        return ClientCredentialsTokenSource(
            http=self._http("CDSE OAuth"),
            token_url=s.cdse_token_url,
            client_id=s.copernicus_client_id,
            client_secret=s.copernicus_client_secret,
        )

    # -- NASA -----------------------------------------------------------

    @cached_property
    def power_extended(self) -> NasaPowerExtendedClient:
        return NasaPowerExtendedClient(
            base_url=self._settings.nasa_power_base_url, http=self._http("NASA POWER")
        )

    @cached_property
    def cmr(self) -> CmrClient:
        return CmrClient(base_url=self._settings.cmr_base_url, http=self._http("NASA CMR"))

    @cached_property
    def eonet(self) -> EonetClient:
        return EonetClient(base_url=self._settings.eonet_base_url, http=self._http("NASA EONET"))

    @cached_property
    def asf(self) -> AsfClient:
        return AsfClient(base_url=self._settings.asf_base_url, http=self._http("ASF Search"))

    @cached_property
    def gibs(self) -> GibsClient:
        return GibsClient(base_url=self._settings.gibs_base_url, http=self._http("NASA GIBS"))

    @cached_property
    def harmony(self) -> HarmonyClient:
        s = self._settings
        return HarmonyClient(
            base_url=s.harmony_base_url, token=s.nasa_earthdata_token, http=self._http("NASA Harmony")
        )

    @cached_property
    def appeears(self) -> AppeearsClient:
        s = self._settings
        return AppeearsClient(
            base_url=s.appeears_base_url,
            username=s.nasa_earthdata_username,
            password=s.nasa_earthdata_password,
            http=self._http("NASA AppEEARS"),
        )

    # -- Copernicus / STAC ----------------------------------------------

    @cached_property
    def cdse(self) -> CdseClient:
        s = self._settings
        return CdseClient(
            odata_url=s.cdse_odata_url,
            download_url=s.cdse_download_url,
            openeo_url=s.cdse_openeo_url,
            http=self._http("Copernicus CDSE"),
            token_source=self._cdse_tokens,
        )

    @cached_property
    def cdse_s3(self) -> CdseS3Locator:
        return CdseS3Locator(endpoint_url=self._settings.cdse_s3_endpoint)

    @cached_property
    def sentinel_hub(self) -> SentinelHubClient:
        return SentinelHubClient(
            base_url=self._settings.sentinel_hub_base_url,
            token_source=self._cdse_tokens,
            http=self._http("Sentinel Hub"),
        )

    @cached_property
    def cdse_stac(self) -> CdseStacClient:
        return CdseStacClient(
            provider="CDSE STAC", base_url=self._settings.cdse_stac_url, http=self._http("CDSE STAC")
        )

    @cached_property
    def earth_search(self) -> StacClient:
        return StacClient(
            provider="Earth Search",
            base_url=self._settings.earth_search_url,
            http=self._http("Earth Search"),
        )

    @cached_property
    def planetary_computer(self) -> PlanetaryComputerStacClient:
        s = self._settings
        return PlanetaryComputerStacClient(
            base_url=s.planetary_computer_stac_url,
            sas_url=s.planetary_computer_sas_url,
            http=self._http("Planetary Computer"),
        )

    @cached_property
    def earth_engine(self) -> EarthEngineClient:
        s = self._settings
        source = (
            ServiceAccountTokenSource(key_file=s.gee_service_account_file)
            if s.gee_service_account_file
            else None
        )
        return EarthEngineClient(
            base_url=s.gee_base_url,
            project=s.gee_project,
            token_source=source,
            http=self._http("Google Earth Engine"),
        )

    # -- Soil / agriculture / weather / terrain -------------------------

    @cached_property
    def soilgrids(self) -> SoilGridsClient:
        s = self._settings
        return SoilGridsClient(
            rest_url=s.soilgrids_rest_url, wcs_url=s.soilgrids_wcs_url, http=self._http("SoilGrids")
        )

    @cached_property
    def wosis(self) -> WosisClient:
        return WosisClient(graphql_url=self._settings.wosis_graphql_url, http=self._http("WoSIS"))

    @cached_property
    def faostat(self) -> FaostatClient:
        s = self._settings
        return FaostatClient(
            api_url=s.faostat_api_url,
            bulk_catalog_url=s.faostat_bulk_catalog_url,
            token=s.faostat_token,
            http=self._http("FAOSTAT"),
            cache_dir=Path(s.resolve_nasa_power_cache_dir()).parent / "faostat",
        )

    @cached_property
    def gaez(self) -> GaezClient:
        return GaezClient(
            http=self._http("FAO GAEZ v5"),
            cache_dir=Path(self._settings.resolve_nasa_power_cache_dir()).parent / "gaez",
        )

    @cached_property
    def open_meteo(self) -> OpenMeteoClient:
        s = self._settings
        return OpenMeteoClient(
            http=self._http("Open-Meteo"),
            forecast_url=s.open_meteo_forecast_url,
            archive_url=s.open_meteo_archive_url,
            flood_url=s.open_meteo_flood_url,
            api_key=s.open_meteo_api_key,
        )

    @cached_property
    def opentopography(self) -> OpenTopographyClient:
        s = self._settings
        return OpenTopographyClient(
            base_url=s.opentopography_base_url,
            api_key=s.opentopography_api_key,
            http=self._http("OpenTopography"),
        )
