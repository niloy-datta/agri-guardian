# GPM IMERG Cross-Validation — Phase 4B.1 (Blocked)

**Status: acquisition blocked on missing NASA Earthdata credentials. No real GPM IMERG data has been
acquired. No cross-validation of the Han monsoon-onset method against IMERG has been performed.** This
document records what was independently verified against live NASA sources in this phase, and exactly
why the phase could not proceed further — per this project's own rule that scientific honesty about a
blocker is more valuable than a fabricated result.

## MEASURED (verified directly against live NASA/GES DISC responses during the review)

Every fact in this section was confirmed by an actual live HTTP request made during this phase's
research and is independently reproducible by re-running the same
request.

- **Product**: GPM IMERG Final Precipitation L3, 1 day, 0.1° × 0.1° (short name `GPM_3IMERGDF`),
  **Version 07** (real granule filenames carry the minor revision string `V07B`). DOI
  `10.5067/GPM/IMERGDF/DAY/07`. Confirmed via NASA's own catalog record
  ([earthdata.nasa.gov/data/catalog/ges-disc-gpm-3imergdf-07](https://www.earthdata.nasa.gov/data/catalog/ges-disc-gpm-3imergdf-07))
  and via the granule's own `NC_GLOBAL` attributes (see below).
- **Granule filename pattern**, confirmed via a live, unauthenticated directory listing at
  `https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDF.07/2020/01/contents.html`:
  `3B-DAY.MS.MRG.3IMERG.<YYYYMMDD>-S000000-E235959.V07B.nc4`.
- **Variable, units, fill value**, confirmed via a live, unauthenticated `.das` metadata request against
  a real granule (`3B-DAY.MS.MRG.3IMERG.20200101-S000000-E235959.V07B.nc4.das`):
  - `precipitation`: units `"mm/day"`, long_name `"Daily mean precipitation rate (combined
    microwave-IR) estimate. Formerly precipitationCal."`, `_FillValue -9999.90039`.
  - This fill value is **not** the same as NASA POWER's `-999.0` — any future implementation must never
    assume the two products share a sentinel.
  - The long_name's "Formerly precipitationCal" naming indicates this is IMERG's calibrated
    (gauge-adjusted) combined microwave-IR estimate, not a purely satellite-only retrieval.
- **Grid layout**, confirmed via a live, unauthenticated `.dds` metadata request: `lon` dimension size
  3600 (360°/0.1°), `lat` dimension size 1800 (180°/0.1°) — i.e. a genuine 0.1° global grid.
- **Product provenance metadata** on the granule itself confirms: `title = "GPM IMERG Final
  Precipitation L3 1 day 0.1 degree x 0.1 degree (GPM_3IMERGDF)"`, `DOI =
  "10.5067/GPM/IMERGDF/DAY/07"`, and an `InputPointer` listing the 48 half-hourly `3B-HHR` granules that
  were aggregated to produce that one daily file (confirming this Level-3 daily product is already a
  proper daily aggregate, not something this project needs to aggregate itself from sub-daily data).
- **Authentication requirement**, confirmed via two independent live requests:
  1. A raw OPeNDAP binary data request (`.dap.nc4`) returned **HTTP 401 "HTTP Basic: Access denied."**
  2. An OPeNDAP ASCII data-slice request for a specific coordinate (`.ascii?precipitation[0][2686][1144]`)
     returned **HTTP 302**, redirecting to `urs.earthdata.nasa.gov/oauth/authorize/...`.
  Both independently confirm the same fact: **actual precipitation values require a NASA Earthdata
  Login account with the "NASA GES DISC DATA ARCHIVE" and "Hyrax in the Cloud" applications explicitly
  authorized**, plus a bearer token or `.netrc`-based login built from that account. Metadata-only
  endpoints (`.das`, `.dds`, directory listings) do not require authentication.
- **Latency/product tiers** (from NASA's own GPM documentation): IMERG has three runs — Early (~4h
  latency), Late (~14h latency), and **Final (~3.5-month latency)**. `GPM_3IMERGDF` (used here) is the
  Final Run daily product.

## COMPUTED (pure, deterministic, verified by direct execution — no live data required)

- **Same Location Contract** (repository rule): resolving the Rajshahi pilot coordinate
  (`latitude=24.37400, longitude=88.60114`, from `app/modules/advisory/pilots/rajshahi_aman.py` —
  never invented or substituted) against IMERG's confirmed 0.1° grid layout:
  - Grid indices: `longitude_index=2686`, `latitude_index=1144` (confirmed by actually issuing that
    exact indexed request against the live server and observing the expected redirect, not a 404 or a
    parse error — i.e. these indices genuinely route to real IMERG data at this coordinate).
  - Grid cell center: **88.6°E, 24.4°N** — not identical to the requested coordinate.
  - Spatial offset between the requested pilot coordinate and the selected grid cell center: computed
    via the haversine formula in `app/integrations/nasa/imerg_client.py::resolve_grid_cell`, verified
    by direct execution and a unit test
    (`tests/test_gpm_imerg_client.py::TestResolveGridCell::test_rajshahi_pilot_coordinate_matches_live_verified_grid_indices`).
- **Overlap-period arithmetic** (not yet applied — no data to compare): IMERG's own coverage begins
  June 2000, per the GPM mission's public record, so an overlap with NASA POWER's existing 2001–2025
  fixture period would in principle be the full 2001–2025 span. This has not been verified against a
  real acquired IMERG record in this phase — see Not Established below.

## INTERPRETATION (what these facts do and do not mean)

- The scaffolded acquisition-layer code (`app/integrations/nasa/imerg_client.py`) can correctly
  construct the exact request NASA expects and correctly detects every authentication-failure mode this
  phase's research actually observed (401, and the specific 302-to-`urs.earthdata.nasa.gov` case) — this
  is consistent with the client being wired to the real, current GES DISC endpoint, not a guessed or
  outdated one.
- This is **not** evidence that the client's (not-yet-written) response-parsing logic would be correct,
  because no authenticated response has ever been observed during the review to parse. Writing a parser
  against an unseen byte layout would be exactly the kind of invented, unverified science this
  project's rules forbid, so it was not written.
- Per this project's own wording rule: IMERG's calibration/gauge-adjustment characteristic (visible in
  its "Formerly precipitationCal" long_name) means a future comparison against NASA POWER must be
  described as **`cross-product precipitation validation`**, never as "ground truth" or "station
  validation" — the two products are not guaranteed to share zero upstream information.

## VALIDATION (what this phase's evidence is sufficient to establish)

- That `GPM_3IMERGDF` V07 is the current, correct, research-appropriate product choice for a
  retrospective comparison against the existing NASA POWER analysis (Final Run, not Early/Late;
  V07/V07B, not a retired version).
- That the Rajshahi pilot coordinate's exact IMERG grid cell, and its offset from the coordinate, are
  known and disclosed, not assumed identical.
- That this project's backend has no working path to acquire real IMERG data today, and exactly why
  (missing NASA Earthdata Login token; the config field `Settings.nasa_earthdata_token` already exists
  as an empty placeholder for this purpose but was never populated).

## NOT ESTABLISHED (everything the Phase 4B.1 brief asked for beyond the above)

None of the following was performed, because all of it requires real acquired IMERG data that this
session cannot obtain:

- Any real IMERG precipitation values for any date or coordinate.
- A committed IMERG fixture, manifest, or checksum entry (Tasks 9/10) — deliberately not created, since
  there is no real evidence to preserve; a fixture with no real data behind it would violate this
  project's standing rule against synthetic evidence disguised as real.
- Offline replay (Task 11).
- Running the existing, unmodified Han `han_agronomic_onset_v1` method against IMERG data (Task 15).
- Year-by-year onset comparison, boundary-clustering comparison, period-shift comparison, or any
  cross-product agreement metric (Tasks 16–19).
- Any extension of `app/compute/han_validation.py`'s deterministic validation policy (Task 23) — not
  extended in this phase, since there is no new evidence to justify a change, and extending it without
  justification would itself violate that module's own design principle.
- Any change to `RAJSHAHI_AMAN_PILOT.decision_enabled` or to
  `docs/references/han_2024_nasa_power_transfer_review.md`'s classification — both remain exactly as
  Phase 4A.2c left them.

## What resolving this would require

1. A NASA Earthdata Login account with the "NASA GES DISC DATA ARCHIVE" and "Hyrax in the Cloud"
   applications authorized (done once, in a browser, by whoever holds the account).
2. A bearer token generated from that account (or a `.netrc` file with its username/password), supplied
   to this project via `Settings.nasa_earthdata_token` (already a config field, never populated).
3. Once a token is available: inspect one real authenticated response to learn its actual byte/text
   layout, only then write and test a parser against that real, observed shape — never before.
4. Build the fixture/manifest/offline-replay layer (mirroring `app/integrations/nasa/power_cache.py`'s
   pattern, per this phase's own Task 10 instruction not to duplicate the checksum algorithm
   unnecessarily) once real evidence exists to store.
5. Only then: run the existing Han method against both products and complete Tasks 15–28.
