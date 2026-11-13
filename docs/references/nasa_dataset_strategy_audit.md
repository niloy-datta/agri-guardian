# NASA Dataset Strategy Audit — Rajshahi Aman Pilot

Audit of two externally-supplied research files (`NASA_Bangladesh_Agriculture_Datasets_updated.md` /
`.xlsx`, and `Bangladesh_64_Districts_NASA_Agri_Dataset_v2.md` / `.xlsx`) against the current Mukti
repository, done to decide the next scientifically defensible step for the Rajshahi Aman pilot's
rainfall-onset problem. **This document is an audit and research note, not an implementation.** No
production code, fixtures, or thresholds were changed as part of writing it.

Research performed: 2026-09-26/27, via live web search and full-text document retrieval in this
review. The two attached files themselves are treated as **research leads**,
not verified scientific truth, per the task's own instruction — nothing in them was imported into
code, and every number in them is marked below as verified, unverified, or outdated based on
independent checking, not based on the file's own confidence.

---

## 1. The exact current problem (from the repo, not the attached files)

- `backend/api/app/compute/agro.py`: pure usable-rain-onset function. Current definition (still the
  one actually wired to the pilot): 7-day window, 20mm cumulative threshold, 7-day dry-spell
  false-start check, searched across the **whole calendar year** (no seasonal restriction).
- `demo_fixtures/analysis/rajshahi_aman_analysis.json` (real, 2001–2025 NASA POWER evidence):
  reference-period (2001–2012) median onset day-of-year **91.5** (~1 Apr), recent-period (2013–2025)
  median **65** (~6 Mar), `shift_days = -26.5`, Mann-Whitney U=35.5, p≈0.0223. Sensitivity at
  15/20/25mm: -26.0 / -26.5 / -8.5 days — directionally consistent, but the onset dates themselves
  (Feb–Apr every year) are Rajshahi's **pre-monsoon nor'wester rain**, not the June monsoon relevant to
  Aman transplanting.
- A follow-up attempt added an opt-in `search_window_start/end_month_day`
  restriction to `OnsetDefinition` and tried May 1–Sep 30 and Jun 1–Aug 31. Both produced a **boundary-
  saturation artifact**: onset landed within days of whichever window-start was chosen, because
  antecedent rainfall by then is already enough to clear a 20mm/7-day threshold almost immediately.
  This capability was kept in `agro.py` (tested, backward-compatible) but **not applied to the pilot**
  — the pilot config (`pilots/rajshahi_aman.py`) and its analysis artifact remain in the unrestricted
  state above.
- `backend/api/app/compute/planting_policy.py`, `app/modules/advisory/{router,schemas,service}.py`,
  `tests/test_planting_policy.py`: a recommendation-API layer was drafted in an earlier session but is
  **uncommitted** and explicitly held back — it must not be wired to real data while the onset
  methodology above is unresolved.
- **Conclusion carried into this audit**: this is a **methodology problem, not a missing-dataset
  problem**. NASA POWER `PRECTOTCORR` for 2001–2025 at the sourced Rajshahi coordinate is already
  real, fetched, checksummed, and sufficient in principle — the 20mm/7-day/7-day-dry-spell rule
  applied to it is simply the wrong rule for detecting an Aman-relevant monsoon transition.

---

## 2. Task 5 finding — a directly applicable, peer-reviewed, Rajshahi-specific methodology exists

**Han, E., Montes, C., Hussain, S.G., & Krupnik, T.J. (2024). "Agronomic monsoon onset definitions to
support planting decisions for rainfed rice in Bangladesh." *Climatic Change*, 177(5), 77.
https://doi.org/10.1007/s10584-024-03736-z** (open-access full text also at
https://pmc.ncbi.nlm.nih.gov/articles/PMC11090806/).

This paper is a near-exact match to Mukti's actual problem:

- It defines monsoon onset from **daily rainfall alone** (BMD gauge data in the paper, but the
  definition itself is data-source-agnostic — it operates on any daily precipitation series,
  including NASA POWER `PRECTOTCORR`).
- It explicitly diagnoses the **same false-start failure mode** Mukti hit: a simple "50mm over 3
  days" rule "risk[s] giving rise to 'false starts' of the monsoon during the pre-monsoon season" —
  i.e. the identical Feb–Apr nor'wester problem found in the real NASA POWER data the review.
- Its recommended definition: *"the first wet day from May 15th of the first wet spell of LWS days
  receiving at least the amount of rainfall AWS, without being followed by a dry spell of LDS days
  receiving less rainfall than ADS in the subsequent 20 days from the onset."* Four parameters (Length
  of initial Wet Spell, Amount of rainfall in that Wet Spell, Length of post-onset Dry Spell, Amount
  of rainfall allowed during that dry spell), fit **per station**, with a fixed **May 15 – Oct 31**
  search window.
- It reports **station-specific fitted values including Rajshahi itself**:

  | Station | LWS (days) | AWS (mm) | LDS (days) | ADS (mm) |
  |---|---|---|---|---|
  | Rajshahi | 3 | 31 | 6 | 11 |
  | Jashore | 3 | 27 | 5 | 17 |
  | Dinajpur | 3 | 34 | 6 | 12 |
  | Barishal | 4 | 55 | 5 | 19 |

- It validates the definition specifically against **Aman rice yield outcomes** via crop-model
  simulation, and reports the benefit concentrated in the two **drier** stations — **Jashore and
  Rajshahi** — exactly Mukti's pilot site: *"Average simulated yields increase up to 7–9%... over the
  two drier locations"* when the dynamic onset (their "Dynamic 2") is used instead of a fixed
  calendar date.
- Rainy/dry-day thresholds in the paper use **≥1mm/day** (wet) and **≤1mm/day** (dry), not 0mm — a
  materially different (and better-justified) dry-day definition than Mukti's current strict-0.0mm
  dry-spell check.

**This is the strongest available fix**: adopting this paper's Rajshahi parameters (LWS=3, AWS=31mm,
LDS=6, ADS=11mm, search window May 15–Oct 31) as `OnsetDefinition`'s values, re-run against the
already-acquired real NASA POWER fixture, is a *methodology correction*, not a new data-acquisition
project — and it is now source-backed instead of an ad hoc parameter guess (which Task 6 of the
brief correctly warns against).

Note two honest caveats for the record:
1. The paper fit these parameters against **BMD gauge data**, not NASA POWER's gridded (~50km)
   product. Applying Rajshahi's fitted parameters to a different (satellite/reanalysis-derived) data
   source is a reasonable, disclosable analytical choice, not a guarantee of an identical result —
   this must be stated explicitly if implemented, not silently assumed.
2. This is one paper. It is peer-reviewed and Rajshahi-specific, which clears this project's source
   bar, but it is not the only possible definition — no further "shopping" for a different paper
   should happen if this one is adopted (see Task 6 guardrail).

---

## 3. Decision matrix

| Dataset / method | Attached-file claim | Current repo use | Official verification status | Scientific value for Rajshahi Aman | Resolution / limitation | Use now? | Why | Next action |
|---|---|---|---|---|---|---|---|---|
| **NASA POWER Daily Point (PRECTOTCORR, T2M_MAX/MIN)** | Core weather backbone, correctly described | **Already implemented and real** — live-verified client, real 2001–2025 fixture, checksummed manifest | VERIFIED CURRENT — endpoint/params live-confirmed in Phase 4A.1 | High — sole evidence source; sufficient for Han et al. (2024)'s definition | Coarse grid (~50km); already known and disclosed | **Yes (already in use)** | It's the one dataset Mukti has actually verified end-to-end | None — keep as-is |
| **Han et al. (2024) agronomic monsoon-onset methodology** | Not in either attached file (found independently) | Not implemented | VERIFIED CURRENT — peer-reviewed, May 2024, open access, Rajshahi-parameterized | **High** — directly targets the exact failure mode found in real data, validated on Aman yield at Rajshahi specifically | Parameters fit on BMD gauge data, not NASA POWER; must disclose this if reused | **Yes — this is the recommended next step** | Fixes the actual bug (wrong onset rule) without adding a new dataset dependency | Phase 4A.2b: replace `OnsetDefinition`'s ad hoc 20mm/7-day rule with Han et al.'s Rajshahi parameters, re-run against existing fixture |
| **GPM IMERG (V07)** | Recommended for "monsoon onset, dry-spell identification" | Not implemented | VERIFIED CURRENT — V07 is the current, non-superseded IMERG version (V06 retired) | Low-to-moderate *right now* — finer spatial grid (0.1°) doesn't fix a methodology bug; could sharpen results **after** the onset definition itself is fixed | N/A | **Not now** | Adding a second, finer-resolution rainfall source before fixing the onset rule would just reproduce the same false-start bug at higher resolution | Revisit only if Han et al.'s method, once applied to NASA POWER, still needs finer spatial validation |
| **SMAP L4 (SPL4SMGP)** | Soil trafficability / puddling readiness | Not implemented | VERIFIED CURRENT — now Version 8 (NSIDC, released Apr 2025); the attached files' GEE asset ID (`SPL4SMGP/007`) is one version behind but still resolvable | Low for the onset-timing question; moderate for a *future* "is the field workable" advisory | Different question entirely (soil workability, not rainfall onset) | **Not now** | Doesn't address the current problem; would be scope creep into a second advisory dimension | Candidate for a later, separate phase — not blocking |
| **GLDAS-2.1 / FLDAS** | Pre-2015 soil-moisture history fill-in | Not implemented | LIKELY CURRENT, not independently re-verified the review | Low for onset timing | Same as SMAP — different question | **Not now** | Same reasoning as SMAP | None |
| **MERRA-2 (M2T1NXFLX etc.)** | "Gridded version of POWER's rainfall source" | Not implemented | LIKELY CURRENT, not independently re-verified | Low — would not resolve a methodology error, and duplicates POWER's own rainfall signal | Redundant with existing NASA POWER precip | **Not now** | No new information for this specific problem | None |
| **MODIS NDVI/EVI (MOD13Q1, Collection 6.1)** | Phenology validation of transplanting/onset dates | Not implemented | VERIFIED CURRENT — Collection **6.1**; **Collection 6 was decommissioned 31 Jul 2023** (the attached files' "V6" links are OUTDATED) | Moderate, **later** — could independently validate that a corrected onset definition's dates line up with observed green-up, per this audit's own Task 5 guidance ("NDVI should validate, not decorate") | Attached files link the retired V6 guide in one place | **Not now, but a good validation step after 4A.2b** | Confirms the fix worked; doesn't identify or fix the current bug | Candidate follow-up: cross-check Han-et-al.-corrected onset years against MCD12Q2 phenology `Greenup` dates for the same pixel |
| **MCD12Q2 (Land Cover Dynamics / phenology dates)** | "Directly tests the planting-date shift" | Not implemented | LIKELY CURRENT (V061), not independently re-verified the review | Same as above — validation only | 500m pixel is coarser than a farm; still a district-representative signal | **Not now** | Same as MODIS NDVI | Same as above |
| **VIIRS (VNP13A1 / VJ113A1)** | NDVI continuity | Not implemented | VERIFIED CURRENT status change: **Suomi NPP (VNP*) data delivery ceases 1 Nov 2026** (NOAA/NASA advisory, confirmed independently) — any future NDVI work must target **NOAA-20 (VJ1, primary) / NOAA-21 (VJ2)**, not VNP13A1 as the attached file assumes | Low right now | The attached files' emphasis on VNP13A1 continuity is already **about to be outdated** | **Not now** | Not needed for the current problem; and the attached files' product choice needs updating regardless | If NDVI validation is later pursued, use VJ1/VJ2, not VNP |
| **HLS (Sentinel-2/Landsat harmonized, 30m)** | Field-level transplanting/harvest detection | Not implemented | LIKELY CURRENT (v2.0), not independently re-verified | Low right now, potentially high for a much later field-scale phase | Heavier pipeline (30m harmonized product); explicitly excluded by every prior phase brief ("No HLS, No Sentinel") | **Not now** | Out of scope per standing project constraints, and not needed for the current problem | None |
| **NASADEM / SRTM** | Elevation/flood-depression mapping | Not implemented | LIKELY CURRENT, not independently re-verified | None for a rainfall-onset problem | Irrelevant to Aman transplant timing | **Not needed** | No relevance to the current gap | None |
| **GRACE / GRACE-FO** | Groundwater depletion, Boro irrigation | Not implemented | LIKELY CURRENT, not independently re-verified | None for Aman onset timing (Boro-season relevance only) | Different crop/season | **Not needed now** | Out of scope for the Aman pilot | None |
| **ECOSTRESS** | Field-scale heat/water stress | Not implemented | VERIFIED CURRENT version change: **Version 3** released 2026 (the attached files' V002 references are becoming OUTDATED) | Low right now | Different question (heat stress, not rainfall onset); explicitly excluded by prior phase briefs | **Not now** | Out of scope; version in attached files is dated | None |
| **64-district baseline table** (`Avg_NDVI_Peak`, `Annual_Rainfall_mm`, `Avg_T2M_C`, `Soil_Moisture_mm`) | Presented as ready-to-use per-district baselines | Not imported | **UNVERIFIED REFERENCE VALUES** — no stated source dataset, period, polygon, processing method, or units precision; cannot be reproduced from the file alone | None until reproduced | Values look plausible but are unsourced by the file's own admission (this audit, not the file, adds that caveat) | **No** | Fails this project's source-gate rule outright | Do not import into any code or database; if district-level baselines are ever needed, regenerate them from a named, reproducible NASA POWER (or other) request, exactly as the Rajshahi pilot fixture was built |

---

## 4. Threshold audit (Task 3)

Every decision threshold appearing in the two attached files, with sourcing status:

| Threshold | Value | Where it appears | Source attached? | Strong enough? | Mukti may use it? |
|---|---|---|---|---|---|
| Rainfall onset trigger | "Daily > 25mm" | `Variable_Specification` sheet | No citation given | No | **No — UNVERIFIED** |
| Wet-tillage suitability | "7-day cumulative > 100mm" | Same sheet | No citation | No | **No — UNVERIFIED** |
| GDD base temperature | "Tb = 10°C" | Same sheet | No citation | No — conflicts with Mukti's own already-flagged-uncertain 8°C (Bouman et al. 2001) figure; two different unsourced/weakly-sourced numbers now compete | **No — UNVERIFIED, and do not silently prefer this 10°C over the existing 8°C citation; both remain non-authoritative** |
| Flowering heat sterility | "T > 35°C at flowering" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Boro nursery cold injury | "T_min < 12°C in Dec–Jan" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Late-Boro heat damage | "T_max > 36°C in Apr–May" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Radiation/yield | "> 18 MJ/m²/day maximizes yield" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Bacterial Leaf Blight risk | "RH > 85% + T > 28°C" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Soil saturation (SMAP) | "sm > 0.35 saturated / sm < 0.15 dry-tillage stress" | Same sheet | No citation | No | **No — UNVERIFIED** |
| Terminal drought (root-zone) | "sm_root > 0.25" | Same sheet | No citation | No | **No — UNVERIFIED** |
| **Han et al. (2024) LWS/AWS/LDS/ADS, per-station** | See Section 2 table | *Not in either attached file* — found independently the review | **Yes — peer-reviewed, Springer, 2024** | **Yes** | **Yes, if implemented as its own sourced phase (4A.2b), with the BMD-vs-POWER data-source caveat disclosed** |

None of the attached files' own thresholds carry a citation to BMD, BRRI, DAE, IRRI, FAO, or a
peer-reviewed source — they read as plausible domain heuristics, not sourced constants, and per this
project's standing rule they must not enter `app/compute/` or any recommendation path. The one
threshold set that clears the bar (Han et al. 2024) was not in the attached files at all; it was
located independently while researching Task 5.

---

## 5. Version / product audit (Task 4)

| Dataset | Attached file's version | Verified current version (the review) | Action |
|---|---|---|---|
| GPM IMERG | V07 | **V07 confirmed current** (V06 retired) | No correction needed if ever used |
| SMAP L4 (SPL4SMGP) | V007 (one file), "V008" noted in the other file's Change Log | **Version 8, released Apr 2025**, confirmed via NSIDC | Attached files are inconsistent with each other; V8 is correct going forward. Note: a geolocation issue affected SMAP data 14 May–28 Jul 2026, under reprocessing |
| MODIS MOD13Q1 | Mostly correctly cites V061, but one file's PDF link points to the V6 guide | **Collection 6.1 (V061) confirmed current; Collection 6 decommissioned 31 Jul 2023** | The V6 PDF link in file 1 (`NASA_Bangladesh_Agriculture_Datasets_updated.md`, Sl 10) is **OUTDATED** — must use the V6.1 guide if ever implemented |
| VIIRS (Suomi NPP, VNP*) | Presented as primary/first-choice NDVI continuity source | **Confirmed: Suomi NPP (VNP) data delivery ends 1 Nov 2026** per NOAA/NASA advisory (Aug 2026) | Attached files' framing (VNP13A1 first, VJ113A1 as backup) is **becoming outdated in real time**; any future implementation must lead with NOAA-20 (VJ1)/NOAA-21 (VJ2) |
| ECOSTRESS | V002 | **Version 3 released 2026** (LP DAAC) | Attached files' V002 references are **OUTDATED** if ECOSTRESS is ever pursued |
| HLS | v2.0 | Not independently re-verified the review (out of scope; excluded by standing project rules regardless) | No action — remains excluded |

---

## 6. Final report

**1. Strongest useful information from the two attached files:** the dataset catalog's structural
inventory (which NASA products exist, their nominal resolution/cadence/coverage) is a reasonable
starting map for *future* phases. Its single most useful trigger was prompting the search that
surfaced Han et al. (2024) — a paper neither attached file actually cites or contains.

**2. Unsafe/unverified values found:** the entire `Variable_Specification` threshold list (25mm onset
trigger, 100mm/7-day tillage rule, Tb=10°C, 35°C/36°C heat thresholds, 12°C cold threshold, 18 MJ
radiation threshold, RH/BLB rule, SMAP 0.35/0.15/0.25 soil-moisture thresholds) — none carry a
citation in the source files. The entire 64-district baseline table (NDVI/rainfall/temperature/soil
moisture per district) is unreproducible from the file alone and must be treated as unverified
reference values only, never imported into code or a database.

**3. Outdated references found:** MOD13Q1 Collection 6 PDF link (retired 2023); SPL4SMGP internal
version inconsistency (file 1 says 007, file 2's own change-log already flags 008); VIIRS product
framing (Suomi NPP delivery ends 1 Nov 2026, imminent); ECOSTRESS V002 (superseded by V3 in 2026).

**4. Datasets verified as useful (for this project, now or later):** NASA POWER (already in use,
sole current evidence source) is the only one immediately useful. GPM IMERG V07, MODIS NDVI/phenology
(Collection 6.1, or VJ1/VJ2 for VIIRS going forward), and SMAP V8 are plausible *future* additions but
none are needed to fix the current problem.

**5. Exact current Rajshahi methodology problem:** the usable-rain onset rule (7-day window, 20mm
cumulative threshold, 7-day 0mm-dry-spell false-start check) detects Rajshahi's pre-monsoon
(Feb–Apr) nor'wester rainfall, not the June monsoon transition relevant to Aman transplanting — this
holds whether the search is unrestricted or restricted to a later calendar window (both produce
artifacts, the latter a boundary-saturation artifact). This is a **methodology defect**, not a data
availability problem.

**6. Best scientifically justified next dataset/method:** **no new dataset** — adopt Han et al.
(2024)'s agronomic monsoon-onset definition (Rajshahi-fitted parameters: LWS=3 days, AWS=31mm, LDS=6
days, ADS=11mm, search window May 15–Oct 31, wet/dry day thresholds at ≥1mm/≤1mm rather than
>0/=0mm), applied to the **already-acquired real NASA POWER `PRECTOTCORR` fixture**.

**7. Should GPM IMERG V07 be next?** No. It would add spatial resolution but not fix the onset
*definition*, which is the actual defect. Revisit only after the Han et al. methodology is
implemented and validated, if a finer-grained cross-check is still wanted.

**8. Is SMAP/GLDAS needed now or later?** Later, and only for a genuinely different question (soil
workability/trafficability for a "is the field ready" advisory) — not related to fixing onset
detection.

**9. Is NDVI needed now or later?** Later, as a *validation* step only (per this brief's own Task 5
guidance) — e.g. checking that Han-et-al.-corrected onset years line up with MCD12Q2 `Greenup` dates
for the pilot's pixel. Not needed to identify or implement the fix itself. If pursued, must use
Collection 6.1 MODIS and, for VIIRS, NOAA-20/21 (VJ1/VJ2) rather than the soon-discontinued Suomi NPP
product the attached files assume.

**10. Exact next implementation phase name:** **Phase 4A.2b — Han et al. (2024) Agronomic Monsoon-Onset
Methodology for Rajshahi Aman** (not started; this audit recommends it but does not implement it).

**11. Exact files that phase should touch:**
- `docs/references/rajshahi_aman_pilot.md` (add the Han et al. 2024 citation and the BMD-vs-POWER
  data-source caveat)
- `backend/api/app/compute/agro.py` (`OnsetDefinition` — parameterize wet/dry-day thresholds at
  configurable mm levels if not already flexible enough, since the current dry-spell check assumes
  strictly 0.0mm; reuse the existing `search_window_*` fields for the May 15–Oct 31 window)
- `backend/api/app/modules/advisory/pilots/rajshahi_aman.py` (replace the current 20mm/7-day/7-day
  values with Han et al.'s Rajshahi-fitted LWS/AWS/LDS/ADS parameters, sourced explicitly)
- `backend/api/scripts/build_pilot_analysis.py` (re-run against the existing fixture — no new fetch
  needed)
- `demo_fixtures/analysis/rajshahi_aman_analysis.json` (regenerated output)
- `backend/api/tests/test_agro_compute.py`, `backend/api/tests/test_pilot_fixture.py` (tests for the
  new parameter set)

**12. Exact files it must NOT touch:** `app/modules/advisory/{router,schemas,service}.py`,
`app/compute/planting_policy.py`, `tests/test_planting_policy.py` (the recommendation-API layer stays
untouched/uncommitted until the onset methodology is validated), anything under `lib/` (Flutter), any
`alembic/` migration, `fields/`/`crop_cycles/`/`risk/`/`rescue/` modules, and no new dataset
integration files (no IMERG/SMAP/GLDAS/NDVI client code) — none are needed for this fix.

**13. Must the current farmer recommendation remain blocked?** **Yes.** Nothing in this audit changes
that. The recommendation-API draft stays uncommitted and the onset methodology remains unvalidated
until Phase 4A.2b (if approved) is implemented and its result is checked for the same
boundary-saturation/false-start failure modes found so far.

No code, fixtures, or thresholds were changed as part of this audit.
