# AgriGuardian: Current Datasets & The "World Champion" Agritech Roadmap

> **Executive Blueprint for NASA Space Apps, Google Solution Challenge & Global Agritech Excellence**  
> *Author: AgriGuardian Engineering & Agronomic Intelligence Team*  
> *Date: November 2026*

---

## 1. Executive Summary

AgriGuardian is designed to bridge the gap between petabytes of Earth observation data and resource-constrained smallholder farmers in vulnerable deltaic regions (such as Bangladesh's Barind Tract, Haor basin, and Coastal salinity belt).

This document provides:
1. **A complete audit of every dataset currently integrated** into the AgriGuardian mobile client and FastAPI backend.
2. **A gap analysis** comparing current capabilities against world-class agricultural advisory platforms.
3. **The "World Champion" Dataset Architecture**: The exact combination of multi-sensor Earth observation, agronomic phenology, hyper-localized soil grids, field-validated pathological vision sets, and sub-seasonal climate models needed to win global competitions (e.g. NASA Space Apps Global Winner, Google Solution Challenge, Imagine Cup).

---

## 2. Datasets Currently Integrated in AgriGuardian

The codebase contains a carefully verified evidence layer across NASA, Copernicus, FAO, and Bangladesh regional sources.

```
                   ┌───────────────────────────────────────────────┐
                   │           AgriGuardian Core Data Hub          │
                   └───────────────────────┬───────────────────────┘
                                           │
         ┌───────────────────┬─────────────┴───────┬───────────────────┐
         │                   │                     │                   │
┌────────┴────────┐ ┌────────┴─────────┐ ┌─────────┴─────────┐ ┌───────┴─────────┐
│   NASA POWER    │ │    GPM IMERG     │ │  Copernicus CDSE  │ │     FAOSTAT     │
│ Agroclimatology │ │  Precipitation   │ │ Sentinel 1 & 2    │ │ Area, Yield &   │
│  (1981–2025)    │ │   (L3 Final)     │ │   (Optical/SAR)   │ │   Production    │
└─────────────────┘ └──────────────────┘ └───────────────────┘ └─────────────────┘
         │                   │                     │                   │
         └───────────────────┼─────────────────────┼───────────────────┘
                             │                     │
                    ┌────────┴─────────┐ ┌─────────┴─────────┐
                    │  NASADEM / SRTM  │ │  BD DAM Markets   │
                    │   30m Elevation  │ │ Daily Wholesale & │
                    │   & Depressions  │ │   Retail Prices   │
                    └──────────────────┘ └───────────────────┘
```

### Detailed Current Inventory

| Dataset / Source | Product Short Name | Spatial / Temporal Resolution | Variables Used in Code | File / Module Location | Operational Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **NASA POWER Agroclimatology** | `POWER_Daily_Point` | 0.5° × 0.625° (~50 km), Daily (1981–Present) | `PRECTOTCORR`, `T2M_MAX`, `T2M_MIN`, `ALLSKY_SFC_SW_DWN`, `RH2M`, `T2MDEW`, `WS2M` | `backend/api/app/integrations/nasa/client.py`, `power_cache.py`, `power_extended.py` | **Live & Cached** (25-year baseline 2001–2025 for 64 districts) |
| **Han 2024 Agronomic Monsoon Model** | Peer-Reviewed Methodology (*Climatic Change* 2024) | Daily point time series | Cumulative rainfall, 7-day wet window, dry spell false-start suppression | `backend/api/app/compute/agro.py`, `han_validation.py` | **Live Deterministic Science** (Resolves pre-monsoon false starts) |
| **NASA GPM IMERG** | `GPM_3IMERGDF` (V07B Final Run) | 0.1° × 0.1° (~10 km), Daily / 30-min | `precipitationCal` (combined microwave-IR estimate) | `backend/api/app/integrations/nasa/imerg_client.py` | **Scaffolded & Verified** (Metadata verified against GES DISC OPeNDAP) |
| **Copernicus CDSE Sentinel-2** | `SENTINEL2_L2A` | 10 m / 20 m, 5-day revisit | Bands B02, B03, B04, B08 (NDVI, EVI), Scene classification | `backend/api/app/integrations/copernicus/cdse.py`, `sentinel_hub.py` | **Live Discovery / Token Architecture** |
| **Copernicus CDSE Sentinel-1** | `SENTINEL-1 GRD_HD` | 10 m / 20 m (RTC 30 m), 6–12 day | VV + VH backscatter for floodwater & rice paddy detection | `backend/api/app/integrations/copernicus/cdse.py` | **Live Discovery & S3 locator** |
| **FAOSTAT** | `QCL` (Crops and Livestock) | National / Sub-national, Annual | Area harvested (ha), Yield (kg/ha), Production (t), CPC codes | `backend/api/app/integrations/fao/faostat.py` | **Bulk zip parsing & token client** |
| **NASA CMR / EONET / ASF** | Earthdata Open APIs | Global, Real-time event streams | Disaster events, natural hazards, SAR granule discovery | `backend/api/app/integrations/nasa/discovery.py` | **Live Keyless APIs** |
| **NASADEM & SRTM** | `NASADEM_HGT` / `SRTMGL1` | 30 m (1 arc-second), Static | Elevation, drainage basin slope, flood depression | `lib/core/constants/api_endpoints.dart`, backend geo models | **Reference Layer** |
| **Bangladesh DAM Market Price** | Department of Agricultural Marketing | Upazila/District wholesale/retail, Daily | Crop market prices (Rice coarse/fine, Potato, Onion, Lentils) | `lib/core/constants/api_endpoints.dart`, marketplace module | **Reference API** |
| **Plant Pathology AI Classifier** | On-device / Edge vision inference | Single leaf close-up | Disease classification, severity grading, confidence scores | `lib/features/plant_scan/`, `lib/screens/plant_scan/` | **Client UX & Diagnostic Protocol** |

---

## 3. What is Missing to Become "World Champion"?

While the current foundation is scientifically rigorous, a project that wins world championships (NASA Space Apps Global Winner, Google Solution Challenge Top 3, Imagine Cup) must solve the **5 Hard Realities of Deltaic Agriculture**:

1. **Monsoon Cloud Cover Blindness**: Optical satellites (Sentinel-2, Landsat) cannot see through clouds during June–August, exactly when farmers must transplant Aman rice.
2. **Surface vs Root-Zone Moisture Mismatch**: Topsoil dries in hours under tropical sun, but roots draw from 30–100 cm depth. Topsoil sensors give false drought alarms.
3. **Lab vs Field Disease Diagnosis**: Classifiers trained on pristine "PlantVillage" lab leaves fail completely when deployed in the wild (mud splatters, uneven tropical sunlight, pest chew holes).
4. **Variety-Specific Phenology**: Rice is not just "rice"—a flash-flood submergence-tolerant variety (BRRI dhan51) behaves entirely differently from a drought-prone high-yielding variety (BRRI dhan28).
5. **Looking Back vs Looking Ahead**: 25 years of historical data proves that climate is shifting, but farmers need **Sub-Seasonal (15–45 day) forward-looking forecasts** to decide whether to sow nursery beds this week.

---

## 4. The "World Champion" Dataset Stack

To dominate international evaluation criteria (**Scientific Rigor**, **Local Impact**, **Technical Execution**, and **Scalability**), AgriGuardian should integrate the following 6 elite datasets:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       WORLD CHAMPION DATASET MATRIX                         │
├─────────────────────┬──────────────────────┬────────────────────────────────┤
│ DOMAIN              │ GOLD STANDARD DATASET│ COMPETITIVE ADVANTAGE          │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 1. Soil & Root-Zone │ NASA SMAP L4 (SPL4SMGP)│ Root-zone (0-100cm) moisture   │
│    Moisture         │ + ISRIC SoilGrids 250m│ + N/P/K, pH & Organic Carbon   │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 2. Cloud-Penetrating│ Sentinel-1 SAR RTC    │ 10m radar penetrates monsoon   │
│    Phenology        │ + OPERA DSWx-S1 (JPL) │ clouds to track rice planting  │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 3. Plant Stress &   │ ECOSTRESS Tiled ESI   │ 70m thermal evapotranspiration │
│    Thermal Stress   │ (ECO_L4T_ESI on ISS) │ captures field-scale drought   │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 4. Forward Forecast │ ECMWF S2S / NOAA CFSv2│ 15-45 day sub-seasonal monsoon │
│    (Predictive)     │ Ensemble Forecasts   │ onset prediction (not just past)│
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 5. Field Pathology  │ PlantDoc + FGVC8     │ In-field noisy real mobile     │
│    (In-the-Wild AI) │ + CGIAR Rice Pest DB │ camera photos, not sterile lab │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ 6. Genetic Variety  │ BRRI/BARI Varietal   │ Degree-day requirements for 40 │
│    Calibration      │ Phenology Calibrations│ localized rice/potato cultivars│
└─────────────────────┴──────────────────────┴────────────────────────────────┘
```

### Detailed Breakdown of the Elite Additions

### 1. NASA SMAP L4 Surface and Root Zone Soil Moisture (`SPL4SMGP`)
- **Agency / Mission:** NASA / JPL.
- **Why it wins:** Standard weather APIs only provide rainfall. SMAP L4 assimilates satellite radiometer observations into a land surface model to output **root-zone soil moisture ($0–100\text{ cm}$)** at 9 km resolution every 3 hours.
- **Farmer Impact:** Tells the farmer if the soil has enough moisture reserve to sustain transplanted seedlings even if rain pauses for 10 days.

### 2. NASA JPL OPERA Dynamic Surface Water Extent (`OPERA_L3_DSWX-S1` & `HLS`)
- **Agency / Mission:** NASA JPL / Copernicus Sentinel-1.
- **Why it wins:** 30m resolution surface water map updated every 2–4 days. It utilizes synthetic aperture radar (SAR) to see straight through heavy monsoon cloud covers.
- **Farmer Impact:** Detects exact floodwater recession in haor wetlands (Sunamganj, Kishoreganj), giving farmers the exact 7-day window to plant dry-season Boro rice.

### 3. NASA ECOSTRESS on ISS: Evaporative Stress Index (`ECO_L4T_ESI`)
- **Agency / Mission:** NASA / International Space Station.
- **Why it wins:** 70-meter field-scale thermal imaging. Detects plant canopy water stress 5 to 7 days **before** the leaves turn yellow or wilting is visible to the human eye.
- **Farmer Impact:** Preemptive drought alert before irreversible yield loss occurs.

### 4. ISRIC SoilGrids 250m Global Comprehensive Soil Map
- **Provider:** International Soil Reference and Information Centre (Wageningen).
- **Why it wins:** Continuous gridded depth layers ($0–5, 5–15, 15–30, 30–60\text{ cm}$) of:
  - Soil Organic Carbon (SOC)
  - pH ($H_2O$)
  - Cation Exchange Capacity (CEC)
  - Clay, silt, and sand fractions
  - Bulk density
- **Farmer Impact:** Calculates specific fertilizer and liming requirements tailored to the farmer's GPS coordinates.

### 5. In-the-Wild Disease Datasets (PlantDoc + FGVC8/9 + CGIAR Rice Pest Atlas)
- **Problem with PlantVillage:** Trained on single leaves picked off plants placed against solid paper backgrounds. Drops from $98\%$ lab accuracy to below $35\%$ on a sunny day in an actual muddy field.
- **The World Champion Solution:**
  - **PlantDoc (IIT Delhi)**: 2,598 in-field images across 13 species in natural lighting with complex background clutter.
  - **Kaggle FGVC8 Plant Pathology**: Thousands of high-resolution real field images with multiple co-occurring diseases.
  - **IRRI/CGIAR South Asian Rice Pest & Disease Library**: Deep coverage of Bacterial Leaf Blight, Sheath Blight, Brown Planthopper, and Blast on local indica cultivars.

### 6. Sub-Seasonal to Seasonal (S2S) Predictive Ensembles (ECMWF & CFSv2)
- **Provider:** ECMWF / WMO WWRP / NOAA.
- **Why it wins:** While NASA POWER tells us what happened over the last 25 years, S2S provides a **15–45 day forward outlook** on monsoon breaks, tropical depressions in the Bay of Bengal, and heatwaves.
- **Farmer Impact:** Transforms the app from a historical dashboard into a **prescriptive early-warning navigation system**.

---

## 5. Architectural Upgrade Plan (Phase NASA-Next)

To integrate these world-class datasets without bloating client devices:

```
[ NASA Earthdata Cloud / CDSE / ISRIC / ECMWF ]
                       │
                       ▼  (Asynchronous Batch / Cloud Compute)
       [ Google Cloud Run / FastAPI Geo-Worker ]
       - GeoTIFF Zonal Statistics Extraction
       - NetCDF4 / Xarray Spatial Slicing
       - Soil Profile & S2S Probability Blending
                       │
                       ▼  (PostgreSQL + PostGIS + Redis Cache)
      [ Ultra-lightweight JSON Envelope API (< 15 KB) ]
                       │
                       ▼  (HTTP / Offline Drift SQLite)
       [ AgriGuardian Flutter Mobile App ]
       - Native Bangla & English Voice Guidance
       - Offline Field Boundary Polygon Caching
       - Instant Decision Advisory Cards
```

1. **Zero-Overhead Mobile Client**: Never parse large NetCDF or GeoTIFF files on mobile. The backend processes spatial rasters into compact JSON envelopes containing median percentiles for the farmer's specific field boundary.
2. **Graceful Fallback Matrix**:
   - Level 1: Live S2S + SMAP L4 + Sentinel-1 SAR (Full connectivity).
   - Level 2: NASA POWER 25-yr Climatology + SoilGrids cache (Standard connectivity).
   - Level 3: Drift SQLite local offline cache (No connectivity in remote fields).

---

## 6. Checklist to Win Global Competitions

| Criterion | Standard Entry | AgriGuardian "World Champion" Standard | Status |
| :--- | :--- | :--- | :--- |
| **Data Authenticity** | Uses mock/demo weather API | Verified live against NASA POWER & Copernicus CDSE APIs with audited provenance | ✅ Implemented |
| **Agronomic Method** | Arbitrary "if rain > 20mm" threshold | Peer-reviewed Han et al. (2024) monsoon onset model tailored to Bangladesh rice | ✅ Implemented |
| **Accessibility** | English-only web portal | Bilingual (Bangla/English) mobile app with native audio voice guidance | ✅ Implemented |
| **Offline Resilience** | App fails when cellular drops | Drift SQLite offline queue + local cache allows full operation in remote fields | ✅ Implemented |
| **All-Weather Remote Sensing** | Optical satellite only (cloud blind) | Sentinel-1 SAR + NASA SMAP root-zone radar moisture integration | 🚀 Blueprint Ready |
| **Predictive Actionability** | Tells what happened yesterday | S2S 30-day forecast + variety-specific planting calendar | 🚀 Blueprint Ready |

---

## 7. Recommended Next Steps

1. **Acquire NASA Earthdata Login Token**:
   - Register at `urs.earthdata.nasa.gov` and authorize the "NASA GES DISC DATA ARCHIVE" and "LP DAAC" applications to unlock full raw GPM IMERG and SMAP L4 programmatic feeds.
2. **Download ISRIC SoilGrids for Bangladesh**:
   - Clip SoilGrids 250m GeoTIFFs for the 64 districts of Bangladesh and ingest soil pH and organic matter into PostgreSQL PostGIS.
3. **Calibrate Plant Pathology Model with PlantDoc**:
   - Retrain or fine-tune MobileNetV4 / YOLOv8-nano on the combined PlantDoc + CGIAR Rice dataset for robust in-the-wild inference.
4. **Deploy Live Pilot for Rajshahi Aman Season**:
   - Validate field advisory outputs against local agricultural extension officers (DAE Bangladesh).
