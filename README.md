# AgriGuardian

### Farmer-centered crop rotation decisions, informed by Earth observation

**NASA Space Apps Challenge 2026 · [Field Shift: Adapting Farms with NASA Data](https://www.spaceappschallenge.org/2026/challenges/adapting-farms-with-nasa-data/) · Bangladesh**

AgriGuardian is a bilingual agricultural decision-support prototype that brings
regional crop calendars, soil information, farmer priorities and NASA climate
data together. It aims to help farmers and agricultural advisers explore crop
rotations under changing rainfall, temperature and water conditions.

> **Project status:** Prototype under development. Satellite products and
> modelled datasets describe areas and historical periods, not exact conditions
> in an individual field. Results require review by farmers and local experts.

## The challenge

Farmers must choose crops and planting windows while balancing seasonal timing,
irrigation access, soil health and uncertain weather. In Bangladesh, fragmented
plots and regional differences make it especially important to distinguish
local observations from information reported at satellite-grid scale.

AgriGuardian targets farmers across **all 64 districts in Bangladesh's eight
divisions** through a Flutter app and FastAPI backend. The location service
uses nationwide district boundaries and regional crop calendars to assemble
location-specific evidence for rotation scenarios. Its historical Rajshahi Aman
pilot is one case study; it is not the default location for the nationwide
rotation service.

## Coverage across Bangladesh

The backend includes location references for all 64 districts across Dhaka,
Chattogram, Rajshahi, Khulna, Barishal, Sylhet, Rangpur and Mymensingh
divisions. It resolves a provided coordinate or field polygon to a district and
selects the corresponding BAMIS regional calendar. The location and calendar
test suite checks all 64 district centroids; it does not establish field-level
accuracy or validate recommendations for every farm.

Boundaries are simplified and points near district borders may resolve
ambiguously. Crop-calendar coverage and external data availability vary by
location and crop. In particular, the Mymensingh-region Aman calendar has a
known source discrepancy and is not served as verified evidence. When evidence
is unavailable, the service reports the gap.

## What the prototype does

- Collects farmer-provided location, farm information and preferences through
  Bangla and English onboarding.
- Analyses historical rainfall and temperatures using NASA POWER, with source,
  period and location context.
- Resolves Bangladesh locations and retrieves regional BAMIS crop-calendar
  information for rotation scenarios.
- Compares feasible crop combinations using calendar overlap, available water
  evidence, irrigation access and supported farmer priorities.
- Reports evidence gaps and uncertainty instead of inventing values. The
  Rajshahi pilot blocks actionable date recommendations when its method has not
  passed the required transfer validation.

The rotation service is a backend capability; an end-to-end farmer-facing
rotation journey has not yet been verified. Existing weather and satellite
showcase screens include demo content and should be interpreted as labelled.

## Data and APIs

The recorded acquisition run was performed on **13 November 2026**. It is a
snapshot, not a live health check. “Acquired” means the run recorded a sample;
it does not alone prove a validated, production-ready integration.

### Evidence used or requested by the prototype

| Dataset / API | Why it is relevant | Current use and limitations |
| --- | --- | --- |
| [NASA POWER Daily](https://power.larc.nasa.gov/docs/services/api/temporal/daily/) | Historical precipitation and temperature for monsoon and growing-condition analysis. | The advisory client requests `PRECTOTCORR`, `T2M_MAX` and `T2M_MIN`; samples were acquired. Meteorology is approximately 0.5° × 0.625° and is not a field measurement. |
| [NASA POWER Monthly and Climatology](https://power.larc.nasa.gov/docs/services/api/temporal/) | Seasonal climate context for exploring crop choices. | Monthly samples were acquired; the rotation service requests climatology as contextual evidence. It is **not currently an input to rotation ranking**. |
| [BAMIS / DAE crop-weather calendars](https://www.bamis.gov.bd/) | Regional crop windows, normal rainfall and water requirements support seasonal and irrigation checks. | The rotation engine uses available calendar rows; uncertainties must be reviewed for each region. The recorded acquisition run did not check this reference dataset. |
| [FAO GAEZ v5](https://gaez.fao.org/) | Crop suitability provides context when comparing scenarios. | Available rainfed and irrigated indices inform screening and tie-breaking. Values are modelled, not observed farm yields; availability varies by crop. The recorded run did not check this dataset. |
| [ISRIC SoilGrids](https://soilgrids.org/) | Modelled soil properties provide context, including pH, organic carbon and nitrogen. | A sample was acquired. The rotation service requests 0–5 cm estimates as context; it does not currently apply soil-suitability thresholds. |
| [BRRI / BBS rice calendar](docs/references/rajshahi_aman_pilot.md) | A Bangladesh-wide baseline for comparing rice transplanting periods. | Used as a national reference in the Rajshahi case study, not as a district-specific recommendation. |
| [Bangladesh district location references](backend/api/app/integrations/reference/bd_locations.py) | District boundaries and GeoNames centroids help select region-specific evidence across Bangladesh. | Covers 64 districts. Coordinates near simplified boundaries can be ambiguous; district centroids are not farm locations. |
| Farmer-provided field and crop information | Farmer inputs provide location, history, irrigation access and priorities. | Inputs are self-reported; onboarding data is stored locally on the device. Backend field-scoped rotation endpoints require authentication. |
| [FAOSTAT](https://www.fao.org/faostat/) | National crop production and yield statistics provide agricultural context. | A Bangladesh sample was acquired. National statistics must not be presented as field-level yield predictions. |

NASA POWER data is drawn from Earth observations and modelling; its grid values
are not direct measurements from a farmer's field. The current rotation engine
uses BAMIS calendar/water evidence, GAEZ suitability and supported preferences
for screening and ranking. SoilGrids and NASA POWER climatology are returned as
context and do not currently change that ranking.

### Registered for further integration

The project catalogues the following products for possible scientific workflows.
The recorded run discovered their catalogue entries or scenes; **it did not
verify acquisition of their observations**:

| Products | Intended purpose |
| --- | --- |
| NASA HLS Sentinel-2 and Landsat; MODIS MOD13Q1; VIIRS VJ113A1; USGS Landsat Collection 2; Copernicus Sentinel-2 | Vegetation condition and seasonal change. |
| NASA MODIS MCD12Q2 and MCD12Q1 | Phenology and land-cover context. |
| NASA IMERG Final and Late | Historical and near-recent rainfall context; the products have different latencies. |
| NASA SMAP L3 and L4; GLDAS; FLDAS | Surface or modelled soil moisture and water-history context. |
| NASA MODIS MOD16A2GF and MOD11A1 | Evapotranspiration and land-surface temperature context. |
| NASA OPERA DSWx; NASADEM; Copernicus Sentinel-1 | Surface water, terrain and radar-based landscape context. |

NASA POWER CMIP6 returned **no usable values** in the recorded Bangladesh
requests. FAO's Global Crop Calendar is registered as a reference, but that
acquisition run did not check it. Discovery is not the same as downloading,
validating or integrating observations. Access to some products requires NASA
Earthdata or Copernicus credentials and appropriate permissions.

See the [30-dataset evidence matrix](docs/evidence/dataset_matrix.md), the
[recorded acquisition results](docs/evidence/live_acquisition.json) and the
[dataset catalogue](nasa_bangladesh_agriculture_datasets_updated.md) for
product-level status, sources and limitations. The authenticated
`GET /api/v1/intelligence/datasets` endpoint exposes recorded dataset status;
it does not represent a live monitoring check.

## Scientific approach and limitations

1. Resolve the location and identify the relevant regional crop calendar.
2. Retrieve available climate, soil and crop-suitability evidence with source
   and scale context.
3. Screen crop combinations using stated calendar and irrigation constraints.
4. Compare feasible scenarios using supported farmer priorities and report
   unsupported priorities or insufficient evidence explicitly.

The current engine does not make validated field-level yield, profit or soil
improvement predictions. NASA POWER climatology and SoilGrids currently provide
context rather than driving its ranking. The [Rajshahi pilot source
record](docs/references/rajshahi_aman_pilot.md) and [method transfer
review](docs/references/han_2024_nasa_power_transfer_review.md) document the
assumptions and safety gate. The pilot point is a city centre, not a farm.

## Technology

| Layer | Technology |
| --- | --- |
| Farmer app | Flutter, Dart, Riverpod and GoRouter |
| API and analysis | Python, FastAPI and deterministic agricultural calculations |
| Storage and services | PostgreSQL/PostGIS, Redis and Alembic |
| Authentication | Firebase Authentication support; Supabase configuration is also present |
| External data | NASA POWER, FAO GAEZ, SoilGrids and other catalogued providers |

## Run locally

Requirements: Flutter SDK, Docker with Compose, and Python 3.12+ for local
backend development. Copy the example configuration and start the services
from the repository root:

```powershell
Copy-Item .env.example .env
docker compose up --build
```

Set the credentials needed for the features you intend to use in your local
`.env`; never commit credentials. The API container applies migrations at
startup. For the Flutter application:

```powershell
flutter pub get
flutter run
```

Device networking and Firebase configuration depend on your environment. NASA
POWER's Daily Point API does not require the `api.nasa.gov` key; other data
providers have their own authentication requirements.

## Tests

```powershell
flutter analyze --no-fatal-infos
flutter test

cd backend/api
python -m pip install -e ".[dev]"
ruff check .
mypy app
pytest -q
```

Backend integration tests need PostgreSQL/PostGIS and Redis; unavailable local
services may cause integration tests to be skipped. CI provides both services.
Check the actual test and CI results for the commit being evaluated.

## Project documentation

- [Bangladesh district location references](backend/api/app/integrations/reference/bd_locations.py)
- [Nationwide district and calendar tests](backend/api/tests/integrations/test_nationwide.py)
- [Regional rotation evidence samples](docs/evidence/rotation_live_runs.json)
- [Dataset evidence matrix](docs/evidence/dataset_matrix.md)
- [Dataset catalogue and source links](nasa_bangladesh_agriculture_datasets_updated.md)
- [Backend architecture](docs/BACKEND_ARCHITECTURE.md)
- [Contribution guidance](CONTRIBUTING.md)
- [Rajshahi Aman historical case study and source record](docs/references/rajshahi_aman_pilot.md)

## Attribution and responsible use

Sources, product versions and limitations should accompany any material used
in a submission. The repository does not currently include a project-wide
license file; the team must confirm its rights and document applicable
third-party licenses before submission. AI-assisted contributions and any
pre-existing work should be disclosed according to the event requirements.

AgriGuardian supports exploration and discussion with agricultural experts; it
does not replace local advice or guarantee crop outcomes.
