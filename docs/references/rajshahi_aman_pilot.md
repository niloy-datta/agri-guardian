# Rajshahi Aman Pilot — Source Record

This document is the single source of truth for every numeric or factual
assumption used by the Rajshahi Aman pilot (`backend/api/app/modules/advisory/pilots/rajshahi_aman.py`).
Nothing in the pilot config may be sourced from anywhere else. If a value
here is later found wrong, this document is corrected first and the code
follows it — not the reverse.

Research performed: 2026-09-24, using live web search and document
retrieval against primary sources.

## Pilot

Rajshahi, Bangladesh — Aman rice (locally grown, rain-fed monsoon-season
rice).

## Location source

- **Source name:** GeoNames (geographical database; ID 1185128)
- **Source URL:** https://www.geonames.org/1185128/rajshahi.html
- **Exact latitude:** 24.37400
- **Exact longitude:** 88.60114
- **What this coordinate represents:** GeoNames feature class/code
  `PPPLA` — "seat of a first-order administrative division". This is
  **Rajshahi city, the administrative seat of Rajshahi Division** — a
  city-center point, not a farm, a field, or a BRRI research station.
  Any per-field precision claim built on top of this pilot must not
  imply otherwise.
- Cross-checked (not used as the citation itself, since it is
  disqualified as a scientific/geospatial authority for this project):
  Wikipedia independently reports very close coordinates for Rajshahi
  city (24°22′28″N 88°36′15″E ≈ 24.3745°N, 88.6042°E), which corroborates
  GeoNames without being the source of record.

## Crop/calendar source

- **Title:** "Rice Crop Calendar of Bangladesh" (table: Time of
  Transplanting / Time of Harvest / Per Acre Seed Requirement, by rice
  type — Aus, Aman, Boro)
- **Organization:** Published via the Bangladesh Rice Research Institute
  (BRRI) official web portal's document storage
  (`brri.portal.gov.bd`-hosted object storage). The table itself cites:
  **Source: BBS (Year Book of Agricultural Statistics-2023)** — the
  Bangladesh Bureau of Statistics, a Bangladesh government statistical
  agency.
- **URL:** https://objectstorage.ap-dcc-gazipur-1.oraclecloud15.com/n/axvjbnqprylg/b/V2Ministry/o/office-brri/2024/12/e703d402c1b24524b570a57bc6806044.pdf
  (retrieved and read directly as a PDF during the review; not a paraphrase)
- **Accessed:** 2026-09-24
- **Exact claim supported, quoted verbatim from the table:**
  - Aman Paddy, **Local Transplant**: Time of Transplanting = "End June
    to Early September"; Time of Harvest = "December to Early January"
  - Aman Paddy, **HYV Transplant**: Time of Transplanting = "Late June
    to Mid-August"; Time of Harvest = "December to Early January"
  - Aman Paddy, Local Broadcast: Time of Transplanting = "Mid-March to
    Mid-April"; Time of Harvest = "Mid-November to Mid-December"
    (a different establishment method; not used by this pilot)
- **Scope honesty:** This calendar is **national** (Bangladesh-wide),
  not specific to Rajshahi or the Barind region. No Rajshahi-specific
  BRRI/DAE transplanting-date publication was located during the review.
  The pilot uses the national HYV Transplant window because modern
  short-duration varieties (HYV) are what BRRI/DAE actively promote in
  Rajshahi division per the DAE source below, but this is the pilot
  applying a national figure to a specific location, not a
  Rajshahi-specific recommendation from BRRI itself. This distinction
  must remain visible in the pilot config and in any UI built on it.
- **Corroborating (not primary) context:** Bangladesh Sangbad Sangstha
  (BSS, the state news agency) reports that DAE's Rajshahi divisional
  office promotes modern short-duration Aman varieties in Rajshahi and
  that transplanting is "usually" possible "until September 15" in the
  region (https://www.bssnews.net/district/293036,
  https://dae.rajshahidiv.gov.bd/en) — consistent with, but not a
  substitute for, the BRRI/BBS table above.

**Terminology used precisely:** the value used is a **transplanting**
window (seedlings moved from nursery to the main field), not a sowing
(nursery seeding) or a broadcast-planting date. These are not
interchangeable and the pilot config field name must say
`transplanting`, never a generic "planting".

## GDD base-temperature source — NOT independently primary-verified

- **Claimed value:** 8°C base temperature (with 30°C optimum and 42°C
  ceiling) for rice phenological development rate.
- **Attributed to:** Bouman, B.A.M., Kropff, M.J., Tuong, T.P., Wopereis,
  M.C.S., ten Berge, H.F.M., van Laar, H.H. (2001). *ORYZA2000: Modeling
  Lowland Rice.* International Rice Research Institute (IRRI) /
  Wageningen University and Research Centre. This is IRRI's own rice
  crop growth model and its calibration program ("DRATES").
- **Verification limits:** Multiple
  independent secondary academic sources (a ScienceDirect paper
  abstract on temperature/phenology prediction error in rice, and
  general-knowledge search summaries) consistently state that
  ORYZA2000's DRATES calibration program assumes default cardinal
  temperatures of 8/30/42°C for rice development. I was **not able to
  open and directly quote the primary Bouman et al. (2001) document
  itself** during the review — the official IRRI PDF
  (`books.irri.org/9712201716_content.pdf`) refused the connection, and
  an academia.edu mirror returned HTTP 403. I did not find this number
  stated in any of the open-access documents I could actually read in
  full (e.g. the PMC-hosted "From ORYZA2000 to ORYZA (v3)" paper does
  not restate the cardinal temperatures).
- **Consequence for this pilot, per the project's source-gate rule:**
  this value is recorded here as a real, named, attributable citation —
  not invented — but it does **not** meet this project's bar for a
  primary-source-verified agronomic constant. It is therefore used, if
  at all, only as **non-authoritative supporting context** (see
  `app/compute/agro.py`'s GDD functions, which still require an explicit
  `base_temperature_c` input from the caller — this document does not
  hard-code 8°C as a verified project constant anywhere in code). No
  "GDD shift" claim is presented to a farmer on the strength of this
  citation alone.

## Baseline transplanting window (summary)

- **Exact window used by the pilot:** Late June – Mid-August (Aman,
  HYV Transplant)
- **What it means:** transplanting date range, not sowing/nursery date,
  not harvest date.
- **Source:** BRRI-hosted "Rice Crop Calendar of Bangladesh" table,
  sourced to BBS Year Book of Agricultural Statistics-2023 (see above).
- **Scope:** national Bangladesh figure, applied to a Rajshahi pilot —
  not a Rajshahi-specific BRRI recommendation.

## Rainfall-onset definition

The 7-day window / 20 mm cumulative threshold / 7-day-dry-spell false-start
rule used by this pilot (`app/compute/agro.py`, `OnsetDefinition`) is
**this project's own analytical definition**, adopted to match the
structure of the NASA Space Apps "Field Shift" challenge guide. It is
**not** attributed to BRRI, DAE, or any agronomy publication, and must
never be presented as if it were a BRRI-defined threshold. It is a
transparent, stated assumption of Mukti's own rainfall-onset computation,
fully configurable and disclosed in every advisory response's
`assumptions` list and `onset_definition` field.

## NASA evidence source

- **Provider:** NASA POWER (Prediction Of Worldwide Energy Resources),
  NASA Langley Research Center.
- **Endpoint:** `https://power.larc.nasa.gov/api/temporal/daily/point`
  (Daily Point API), `community=AG`, `time-standard=LST`.
- **Verification:** confirmed against a real, live NASA POWER HTTP 200
  response during Phase 4A.1 development (see
  `app/integrations/nasa/client.py` module docstring).

## Summary table

| Assumption | Value | Source | Verification level |
|---|---|---|---|
| Pilot coordinate | 24.37400, 88.60114 (Rajshahi city, seat of Rajshahi Division) | GeoNames ID 1185128 | Primary-source read directly |
| Aman baseline transplanting window | Late June – Mid-August (HYV Transplant) | BRRI-hosted crop calendar, sourced to BBS Year Book of Agricultural Statistics-2023 | Primary-source read directly (national scope, not Rajshahi-specific) |
| Rainfall-onset definition (7d/20mm/7d dry spell) | Project-defined | Mukti's own analytical choice, matching the challenge guide's structure | Not an agronomy citation — disclosed as such |
| GDD base temperature | 8°C (cited) | Bouman et al. 2001, ORYZA2000 (IRRI) | **Secondary corroboration only** — primary document not directly quoted during the review; treated as non-authoritative supporting context, not a verified project constant |
| NASA evidence | NASA POWER Daily Point API | power.larc.nasa.gov | Live-verified |
