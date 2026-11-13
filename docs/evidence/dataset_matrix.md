# Dataset acquisition evidence matrix

Recorded run: 2026-11-13T07:19:30.432916+00:00. This is historical evidence, not a live health check.

ACQUIRED is a recorded sample, not proof of a complete production pipeline. DISCOVERED is metadata only. Validation, feature integration, and individual test coverage have not yet been verified by this report.

| # | Dataset | Access | Acquisition evidence | Blocker / next verification |
|---|---|---|---|---|
| 01 | NASA POWER Daily Agroclimatology | nasa_power | ACQUIRED | Sample recorded; validate and verify feature integration. |
| 02 | BRRI / BBS Rice Crop Calendar of Bangladesh | reference | NOT_CHECKED | No acquisition evidence in this run. |
| 03 | GeoNames - Rajshahi Location | reference | NOT_CHECKED | No acquisition evidence in this run. |
| 04 | Farmer Field, Crop History and Priorities | first_party | NOT_CHECKED | No acquisition evidence in this run. |
| 05 | ISRIC SoilGrids 2.0 Soil Properties | soilgrids_wcs | ACQUIRED | Sample recorded; validate and verify feature integration. |
| 06 | FAO GAEZ v5 Crop Suitability | gaez | NOT_CHECKED | No acquisition evidence in this run. |
| 07 | Bangladesh BAMIS / DAE Crop Weather Calendar | reference | NOT_CHECKED | No acquisition evidence in this run. |
| 08 | FAO Global Crop Calendar | reference | NOT_CHECKED | No acquisition evidence in this run. |
| 09 | FAOSTAT Crops and Livestock Products | faostat | ACQUIRED | Sample recorded; validate and verify feature integration. |
| 10 | NASA HLS v2.0 Sentinel-2 Surface Reflectance (HLSS30) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 11 | NASA HLS v2.0 Landsat Surface Reflectance (HLSL30) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 12 | NASA GPM IMERG Final Daily v07 (GPM_3IMERGDF) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 13 | NASA SMAP L4 Soil Moisture v8 (SPL4SMGP) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 14 | NASA MODIS Terra Vegetation Indices v061 (MOD13Q1) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 15 | NASA MODIS Land Cover Dynamics v061 (MCD12Q2) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 16 | NASA MODIS Land Cover Type v061 (MCD12Q1) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 17 | NASA MODIS Evapotranspiration v061 (MOD16A2GF) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 18 | NASA MODIS Land Surface Temperature v061 (MOD11A1) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 19 | NASA GPM IMERG Late Run Daily v07 (GPM_3IMERGDL) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 20 | NASA POWER Monthly Agroclimatology | nasa_power | ACQUIRED | Sample recorded; validate and verify feature integration. |
| 21 | NASA POWER CMIP6 Climate Projection Service | nasa_power | NO_DATA | No usable values in recorded request; investigate coverage and parameters. |
| 22 | NASA SMAP Enhanced L3 Daily Soil Moisture v6 (SPL3SMP_E) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 23 | NASA OPERA Dynamic Surface Water Extent from HLS v1 | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 24 | NASA NASADEM Global Elevation Model (NASADEM_HGT) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 25 | NASA GLDAS-2.1 Noah Land-Surface (GLDAS_NOAH025_3H) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 26 | NASA FLDAS Noah Monthly (FLDAS_NOAH01_C_GL_M) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 27 | NASA VIIRS NOAA-20 Vegetation Indices v002 (VJ113A1) | cmr | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 28 | USGS Landsat Collection 2 Level-2 Surface Reflectance | stac | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 29 | Copernicus Sentinel-1 SAR GRD | asf | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |
| 30 | Copernicus Sentinel-2 Level-2A Surface Reflectance | stac | DISCOVERED | Metadata only; obtain actual data and verify processing and authentication. |

NASA POWER CMIP6: PRECTOTCORR is a supported parameter, daily coverage is 2015–2100, and missing values may occur within the coverage area. [NASA POWER Projection API](https://power.larc.nasa.gov/docs/services/api/projection/).
