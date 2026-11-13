# AgriGuardian

A new Flutter project.

## Agricultural and Earth observation data

AgriGuardian is a crop-rotation decision-support prototype. The code uses NASA
POWER historical rainfall and temperature in its advisory analysis, alongside
sourced crop-calendar and location references. The rotation service also has
paths for BAMIS calendars, FAO GAEZ suitability, SoilGrids and NASA POWER
monthly climate evidence. Availability depends on the location and provider;
missing evidence is reported rather than replaced with invented observations.

The recorded acquisition run on **13 November 2026** retrieved samples from
NASA POWER Daily, NASA POWER Monthly, ISRIC SoilGrids and FAOSTAT. A retrieved
sample alone does not establish a complete, validated production integration.

| Data | Recorded status in that run |
| --- | --- |
| NASA POWER Daily and Monthly; ISRIC SoilGrids; FAOSTAT | Sample data acquired |
| BRRI/BBS crop calendar; GeoNames locations; farmer field and crop history; FAO GAEZ; BAMIS/DAE calendar; FAO crop calendar | Not checked by that acquisition run; some reference data or service code is present in the project |
| NASA HLS Sentinel-2 and Landsat; IMERG Final and Late; SMAP L3 and L4; MODIS MOD13Q1, MCD12Q2, MCD12Q1, MOD16A2GF and MOD11A1; OPERA DSWx; NASADEM; GLDAS; FLDAS; VIIRS VJ113A1; USGS Landsat Collection 2; Copernicus Sentinel-1 and Sentinel-2 | Catalogue records discovered; actual observations were not verified as acquired in that run |
| NASA POWER CMIP6 | The recorded requests returned no usable data |

These are historical results, not current provider health or proof that all 30
datasets are connected to farmer decisions. See the [30-dataset evidence
matrix](docs/evidence/dataset_matrix.md), [recorded acquisition
results](docs/evidence/live_acquisition.json), and the [dataset
catalogue](nasa_bangladesh_agriculture_datasets_updated.md) for product names,
intended uses, limitations and sources. Satellite and model grids represent
areas larger than individual farms; farmers should review results with local
agricultural expertise.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
