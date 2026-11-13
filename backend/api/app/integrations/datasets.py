"""The 30 *datasets* the project uses, and how each one is reached.

`registry.py` catalogues the 30 *APIs* (transport). This module is the
layer above it: for every dataset named in the project's data statement it
records the exact product identifier(s), which integration client serves
it, its native resolution, what the project uses it for, and the caveat
that must travel with any number derived from it.

`discover()` turns a catalogue entry into a live search (CMR granules or
STAC items) through `IntegrationHub`, so callers never hard-code a short
name or collection id in application code.

Every CMR short name/version and AppEEARS product/layer id below was
confirmed live on 2026-11-13; concept ids and DOIs are recorded in
`dataset_evidence.py`. `id_confirmed=False` remains only where no
provider listing has confirmed the id. `confirm_appeears_ids()` checks them against AppEEARS'
keyless product catalogue; run it (or the smoke script) before relying on
them.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time
from enum import StrEnum
from typing import TYPE_CHECKING, Any

from app.integrations.common.errors import IntegrationValidationError
from app.integrations.registry import INTEGRATIONS

if TYPE_CHECKING:
    from app.integrations.hub import IntegrationHub


class Access(StrEnum):
    POWER = "nasa_power"  # NasaPowerClient / NasaPowerExtendedClient
    CMR = "cmr"  # CMR granule discovery (+ Harmony / AppEEARS / OPeNDAP to fetch)
    STAC = "stac"  # Earth Search / Planetary Computer / CDSE STAC
    ASF = "asf"  # ASF Search (Sentinel-1)
    SOILGRIDS = "soilgrids_wcs"
    FAOSTAT = "faostat"
    GAEZ = "gaez"  # FAO GAEZ v5 public GeoTIFFs (app.integrations.fao.gaez)
    REFERENCE = "reference"  # static, cited reference values held in code
    FIRST_PARTY = "first_party"  # collected from the farmer in the app


@dataclass(frozen=True, slots=True)
class DatasetSpec:
    number: int
    key: str
    name: str
    access: Access
    use: str
    caveat: str
    integrations: tuple[int, ...]
    """Numbers in `registry.INTEGRATIONS` that serve this dataset."""
    cmr_short_name: str | None = None
    cmr_version: str | None = None
    appeears_id: str | None = None
    stac: tuple[tuple[str, str], ...] = ()
    """(hub attribute, collection id) pairs, preferred first."""
    resolution: str | None = None
    parameters: tuple[str, ...] = ()
    id_confirmed: bool = True
    source_url: str | None = None
    extra: dict[str, Any] = field(default_factory=dict)


def _d(number: int, key: str, name: str, access: Access, use: str, caveat: str,
       integrations: tuple[int, ...], **kw: Any) -> DatasetSpec:  # fmt: skip
    return DatasetSpec(number, key, name, access, use, caveat, integrations, **kw)


A = Access

DATASETS: tuple[DatasetSpec, ...] = (
    _d(1, "power_daily", "NASA POWER Daily Agroclimatology", A.POWER,
       "Daily PRECTOTCORR, T2M_MAX, T2M_MIN 2001-2025 for monsoon onset and Aman "
       "planting-window shift analysis in Rajshahi.",
       "0.5 x 0.625 deg reanalysis grid cell, not a station or field measurement.",
       (1,), parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"), resolution="0.5 x 0.625 deg",
       extra={"community": "AG", "start_year": 2001, "end_year": 2025}),
    _d(2, "brri_aman_calendar", "BRRI / BBS Rice Crop Calendar of Bangladesh", A.REFERENCE,
       "National Aman HYV transplanting window as the seasonal reference for the "
       "Rajshahi pilot.",
       "National calendar; not a field-specific crop recommendation.",
       (), source_url="app.integrations.reference.crop_calendars:BRRI_AMAN_HYV_TRANSPLANT"),
    _d(3, "geonames_rajshahi", "GeoNames - Rajshahi Location", A.REFERENCE,
       "Rajshahi city-centre coordinates (24.374, 88.60114) locating the historical "
       "NASA POWER pilot.",
       "Administrative city-centre point (GeoNames 1185128), not a measured farm boundary.",
       (), source_url="https://www.geonames.org/1185128",
       extra={"geonameid": 1185128, "lat": 24.374, "lon": 88.60114}),
    _d(4, "farmer_profile", "Farmer Field, Crop History and Priorities", A.FIRST_PARTY,
       "Farmer-selected field coordinates, previous crops, irrigation access, budget and "
       "preferred outcomes to personalise and explain rotation comparisons.",
       "Self-reported; used only with consent and only for that farmer's own scenarios.",
       (), source_url="app.integrations.reference.farmer_profile:FarmerRotationProfile"),
    _d(5, "soilgrids", "ISRIC SoilGrids 2.0 Soil Properties", A.SOILGRIDS,
       "Estimated pH, organic carbon, nitrogen and texture with uncertainty to screen "
       "crop suitability.",
       "Modelled 250 m estimates with prediction intervals; obtain via WCS (REST is "
       "paused and returns null for Bangladesh points).",
       (24,), resolution="250 m",
       parameters=("phh2o", "soc", "nitrogen", "clay", "sand", "silt")),
    _d(6, "gaez_v5", "FAO GAEZ v5 Crop Suitability", A.GAEZ,
       "Agro-ecological suitability, climatic constraints and attainable yield to compare "
       "crops under rainfed and irrigated conditions.",
       "Modelled suitability index (RES05-SXX, 5 arc-min ~9 km, 2001-2020 AgERA5); "
       "not observed yields. No lentil/jute crop; rapeseed is a labelled mustard proxy.",
       (), source_url="https://storage.googleapis.com/fao-gismgr-gaez-v5-data/DATA/GAEZ-V5/",
       resolution="5 arc-min", extra={"mapset": "RES05-SXX", "period": "HP0120"}),
    _d(7, "bamis_dae_calendar", "Bangladesh BAMIS / DAE Crop Weather Calendar", A.REFERENCE,
       "Aman, Boro, mustard and lentil calendars to validate rotation timing.",
       "Rows enter the system only via a cited CSV (see crop_calendars.load_calendar_csv).",
       (), source_url="https://www.bamis.gov.bd/"),
    _d(8, "fao_crop_calendar", "FAO Global Crop Calendar", A.REFERENCE,
       "Crop-specific sowing and harvest seasons to cross-check rotation sequences.",
       "Coverage is uneven; absence of a row is 'no published data', not 'no conflict'.",
       (), source_url="https://cropcalendar.apps.fao.org/"),
    _d(9, "faostat_qcl", "FAOSTAT Crops and Livestock Products", A.FAOSTAT,
       "Bangladesh production, harvested area and yield statistics as national context.",
       "National aggregates; never used for individual-farm yield prediction.",
       (26,), extra={"domain": "QCL", "area_code": 16}),
    _d(10, "hls_s30", "NASA HLS v2.0 Sentinel-2 Surface Reflectance (HLSS30)", A.CMR,
       "30 m NDVI, seasonal vegetation change and field visualisation with cloud masking.",
       "Mask with the Fmask QA band before computing NDVI.",
       (6, 7, 8, 9), cmr_short_name="HLSS30", cmr_version="2.0", appeears_id="HLSS30.020",
       resolution="30 m", parameters=("B04", "B8A", "Fmask")),
    _d(11, "hls_l30", "NASA HLS v2.0 Landsat Surface Reflectance (HLSL30)", A.CMR,
       "Landsat-based HLS to densify crop-condition time series.",
       "Mask with Fmask; L30 NIR band is B05 (S30 uses B8A).",
       (6, 7, 8, 9), cmr_short_name="HLSL30", cmr_version="2.0", appeears_id="HLSL30.020",
       resolution="30 m", parameters=("B04", "B05", "Fmask")),
    _d(12, "imerg_final", "NASA GPM IMERG Final Daily v07 (GPM_3IMERGDF)", A.CMR,
       "Daily satellite precipitation to cross-check POWER rainfall and monsoon onset.",
       "0.1 deg; Final Run lags ~3.5 months.",
       (6, 7, 10), cmr_short_name="GPM_3IMERGDF", cmr_version="07", resolution="0.1 deg"),
    _d(13, "smap_l4", "NASA SMAP L4 Soil Moisture v8 (SPL4SMGP)", A.CMR,
       "Surface and root-zone soil moisture to explain drought or seasonal constraints.",
       "9 km model-assimilation product; disclose the scale.",
       (6, 7, 8, 9), cmr_short_name="SPL4SMGP", cmr_version="008", appeears_id="SPL4SMGP.008",
       resolution="9 km", parameters=("Geophysical_Data_sm_surface", "Geophysical_Data_sm_rootzone")),
    _d(14, "mod13q1", "NASA MODIS Terra Vegetation Indices v061 (MOD13Q1)", A.CMR,
       "250 m NDVI/EVI 16-day series to cross-check HLS seasonal cycles.",
       "Apply the VI Quality / pixel-reliability flags.",
       (6, 8, 9), cmr_short_name="MOD13Q1", cmr_version="061", appeears_id="MOD13Q1.061",
       resolution="250 m", parameters=("_250m_16_days_NDVI", "_250m_16_days_EVI")),
    _d(15, "mcd12q2", "NASA MODIS Land Cover Dynamics v061 (MCD12Q2)", A.CMR,
       "Annual greenup / phenology dates to test crop-calendar assumptions.",
       "500 m; phenology of the pixel, not of a specific crop.",
       (6, 8, 9), cmr_short_name="MCD12Q2", cmr_version="061", appeears_id="MCD12Q2.061",
       resolution="500 m", parameters=("Greenup", "Peak", "Dormancy")),
    _d(16, "mcd12q1", "NASA MODIS Land Cover Type v061 (MCD12Q1)", A.CMR,
       "Yearly land-cover class to screen broad cropland context.",
       "Classes (e.g. IGBP 12 Croplands) are not crop species.",
       (6, 8, 9), cmr_short_name="MCD12Q1", cmr_version="061", appeears_id="MCD12Q1.061",
       resolution="500 m", parameters=("LC_Type1",)),
    _d(17, "mod16a2gf", "NASA MODIS Evapotranspiration v061 (MOD16A2GF)", A.CMR,
       "8-day ET to compare seasonal water-use pressure between rotations.",
       "500 m gap-filled modelled ET.",
       (6, 8, 9), cmr_short_name="MOD16A2GF", cmr_version="061", appeears_id="MOD16A2GF.061",
       resolution="500 m", parameters=("ET_500m", "PET_500m")),
    _d(18, "mod11a1", "NASA MODIS Land Surface Temperature v061 (MOD11A1)", A.CMR,
       "Daily LST for regional heat exposure during crop seasons.",
       "Land-surface (skin) temperature, not 2 m air temperature.",
       (6, 8, 9), cmr_short_name="MOD11A1", cmr_version="061", appeears_id="MOD11A1.061",
       resolution="1 km", parameters=("LST_Day_1km", "LST_Night_1km")),
    _d(19, "imerg_late", "NASA GPM IMERG Late Run Daily v07 (GPM_3IMERGDL)", A.CMR,
       "Near-recent satellite rainfall for timely monitoring.",
       "Preliminary; keep strictly separate from Final Run historical analysis.",
       (6, 7, 10), cmr_short_name="GPM_3IMERGDL", cmr_version="07", resolution="0.1 deg"),
    _d(20, "power_monthly", "NASA POWER Monthly Agroclimatology", A.POWER,
       "Monthly rainfall and temperature to compare seasons across crop years.",
       "Month key 13 is the annual mean and is split out.",
       (3,), parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"), resolution="0.5 x 0.625 deg"),
    _d(21, "power_cmip6", "NASA POWER CMIP6 Climate Projection Service", A.POWER,
       "Scenario projections to compare long-term rotation resilience.",
       "Projections, not forecasts. Live check returned only fill values for Bangladesh; "
       "has_coverage=False blocks use.",
       (5,)),
    _d(22, "smap_l3e", "NASA SMAP Enhanced L3 Daily Soil Moisture v6 (SPL3SMP_E)", A.CMR,
       "Radiometer surface soil moisture to compare with SMAP L4.",
       "9 km posting; use retrieval_qual_flag, gaps over dense vegetation / water.",
       (6, 8, 9), cmr_short_name="SPL3SMP_E", cmr_version="006", appeears_id="SPL3SMP_E.006",
       resolution="9 km", parameters=("Soil_Moisture_Retrieval_Data_AM_soil_moisture",
                                      "Soil_Moisture_Retrieval_Data_AM_retrieval_qual_flag")),
    _d(23, "opera_dswx_hls", "NASA OPERA Dynamic Surface Water Extent from HLS v1", A.CMR,
       "Observed surface-water class near fields.",
       "Observation of water occurrence, not a flood forecast.",
       (6, 7), cmr_short_name="OPERA_L3_DSWX-HLS_V1", cmr_version="1.0", resolution="30 m"),
    _d(24, "nasadem", "NASA NASADEM Global Elevation Model (NASADEM_HGT)", A.CMR,
       "Elevation and derived slope for drainage / topographic context.",
       "1 arc-sec (~30 m); disclose DEM vertical error in flat deltaic terrain.",
       (6, 30), cmr_short_name="NASADEM_HGT", cmr_version="001", resolution="30 m",
       stac=(("planetary_computer", "nasadem"),), extra={"static": True}),
    _d(25, "gldas_noah", "NASA GLDAS-2.1 Noah Land-Surface (GLDAS_NOAH025_3H)", A.CMR,
       "Model soil-moisture / water histories where SMAP lacks coverage.",
       "0.25 deg, 3-hourly, model output.",
       (6, 7, 10), cmr_short_name="GLDAS_NOAH025_3H", cmr_version="2.1", resolution="0.25 deg"),
    _d(26, "fldas_noah", "NASA FLDAS Noah Monthly (FLDAS_NOAH01_C_GL_M)", A.CMR,
       "Monthly model soil moisture and ET for long-term water constraints.",
       "0.1 deg monthly model output.",
       (6, 7, 10), cmr_short_name="FLDAS_NOAH01_C_GL_M", cmr_version="001",
       resolution="0.1 deg"),
    _d(27, "vj113a1", "NASA VIIRS NOAA-20 Vegetation Indices v002 (VJ113A1)", A.CMR,
       "500 m NDVI/EVI for MODIS continuity and cross-sensor comparison.",
       "Apply cloud and pixel-reliability flags.",
       (6, 8, 9), cmr_short_name="VJ113A1", cmr_version="002", appeears_id="VJ113A1.002",
       resolution="500 m", parameters=("500_m_16_days_NDVI", "500_m_16_days_pixel_reliability")),
    _d(28, "landsat_c2_l2", "USGS Landsat Collection 2 Level-2 Surface Reflectance", A.STAC,
       "Independent 30 m crop-condition checks and historical comparisons.",
       "Apply scale 0.0000275 / offset -0.2 and QA_PIXEL cloud masks.",
       (21, 22), stac=(("earth_search", "landsat-c2-l2"), ("planetary_computer", "landsat-c2-l2")),
       resolution="30 m"),
    _d(29, "s1_grd", "Copernicus Sentinel-1 SAR GRD", A.ASF,
       "Radar backscatter trends when monsoon cloud blocks optical imagery.",
       "SAR interpretation needs field validation.",
       (12, 14, 22), stac=(("planetary_computer", "sentinel-1-grd"),), resolution="10 m",
       extra={"asf_platform": "Sentinel-1", "processing_level": "GRD_HD"}),
    _d(30, "s2_l2a", "Copernicus Sentinel-2 Level-2A Surface Reflectance", A.STAC,
       "Optical reflectance and NDVI for monitoring, compared with HLS.",
       "Mask with the SCL band; cross-check against HLSS30.",
       (14, 16, 17, 21, 22),
       stac=(("earth_search", "sentinel-2-l2a"), ("planetary_computer", "sentinel-2-l2a")),
       resolution="10 m"),
)  # fmt: skip

_BY_KEY = {d.key: d for d in DATASETS}


def get_dataset(key_or_number: str | int) -> DatasetSpec:
    if isinstance(key_or_number, int):
        for d in DATASETS:
            if d.number == key_or_number:
                return d
    elif key_or_number in _BY_KEY:
        return _BY_KEY[key_or_number]
    raise KeyError(f"unknown dataset: {key_or_number!r}")


def integrations_for(spec: DatasetSpec) -> list[str]:
    """Names of the transport APIs (registry.py) that serve a dataset."""
    by_number = {i.number: i.name for i in INTEGRATIONS}
    return [by_number[n] for n in spec.integrations]


@dataclass(frozen=True, slots=True)
class DiscoveryHit:
    dataset: str
    route: str
    item_id: str
    start: str | None
    links: list[str]


async def discover(
    hub: IntegrationHub,
    key: str,
    *,
    bbox: tuple[float, float, float, float],
    start: date,
    end: date,
    limit: int = 10,
) -> list[DiscoveryHit]:
    """Find granules / scenes of a catalogued remote-sensing dataset."""
    spec = get_dataset(key)
    if spec.access is Access.CMR:
        static = bool(spec.extra.get("static"))  # e.g. NASADEM: one epoch, no date filter
        granules, _ = await hub.cmr.search_granules(
            short_name=spec.cmr_short_name,
            bbox=bbox,
            start=None if static else start,
            end=None if static else end,
            page_size=limit,
        )
        return [
            DiscoveryHit(spec.key, "cmr", g.concept_id, g.time_start, g.links) for g in granules
        ]
    if spec.stac:
        attr, collection = spec.stac[0]
        client = getattr(hub, attr)
        result = await client.search(
            collection=collection,
            bbox=bbox,
            start=datetime.combine(start, time.min, UTC),
            end=datetime.combine(end, time.max, UTC),
            limit=limit,
        )
        return [
            DiscoveryHit(
                spec.key,
                f"stac:{attr}",
                item.id,
                item.datetime.isoformat() if item.datetime else None,
                list(item.assets.values()),
            )
            for item in result.items
        ]
    raise IntegrationValidationError(
        f"dataset {key!r} ({spec.access}) is not searchable by granule/scene",
        provider="datasets",
    )


async def confirm_appeears_ids(hub: IntegrationHub) -> dict[str, bool]:
    """Check every catalogued AppEEARS id against the live product list."""
    products, _ = await hub.appeears.list_products()
    live = {p.product_id for p in products}
    return {d.key: d.appeears_id in live for d in DATASETS if d.appeears_id}
