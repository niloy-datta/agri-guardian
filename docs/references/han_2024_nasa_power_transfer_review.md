# Han et al. (2024) → NASA POWER Transfer Review — Rajshahi Aman Pilot

This document assesses whether applying Han et al. (2024)'s Rajshahi-fitted Dynamic-2 monsoon-onset
parameters (BMD gauge data, 1981–2017) to Mukti's real NASA POWER evidence (grid/model-blended,
2001–2025) produces a plausible result. This is a **plausibility check, not a unit test** — the paper
used a different data source and a different period, so exact equality with the paper's own numbers is
neither expected nor required. See `docs/references/han_2024_agronomic_onset.md` for the algorithm
and citation, and `demo_fixtures/analysis/rajshahi_aman_han_2024_analysis.json` /
`rajshahi_aman_method_comparison.json` for the machine-generated evidence this review reads from.

## What is being compared

| | Paper | Mukti |
|---|---|---|
| Data source | BMD ground-station daily observations | NASA POWER Daily Point (~0.5°×0.625° grid, model/satellite-blended) |
| Location representation | Point station | Grid cell nearest Rajshahi city center (see `rajshahi_aman_pilot.md` for the coordinate-meaning caveat) |
| Period | 1981–2017 (36 years) | 2001–2025 (25 years) |
| Parameters used | Fitted on this same BMD data | Rajshahi's fitted parameters, applied unchanged to a different data source |

## Real NASA POWER result (source: `rajshahi_aman_han_2024_analysis.json`, fixture SHA-256
`47a2fb929709a7732f64dad395b070bb222c6d1d959ef915398938a81cffb713`)

- **Onset date range**: 2001-05-19 (earliest) to 2025-05-16 across all found years, with the single
  latest onset 2005-06-29. All 25 years fall within **May 15 – June 29**.
- **Month distribution**: 19 years in May, 6 years in June.
- **No-onset years**: **0 of 25** — every year found a qualifying onset within the search window.
- **False-onset dry-spell rejections**: 9 total across 25 years, concentrated in **2014 (4
  rejections)** and **2023 (5 rejections)** — the LDS=6/ADS=11mm false-start rule is demonstrably
  active, not a no-op.
- **Onsets within 3 days of the May 15 search-window start**: **7 of 25 (28%)**.
- Reference period (2001–2012) median onset DOY 144.0 (~24 May); recent period (2013–2025) median
  DOY 138 (~18 May); `shift_days = -6.0`. Mann-Whitney U=37.5, p≈0.029.

## Comparison against `usable_rain_v1` (the project's original, unrestricted definition)

The original method (`agro.py`, 7-day/20mm/7-day dry-spell, no seasonal restriction) detects onset in
**February–April** in almost every year — Rajshahi's pre-monsoon nor'wester rainfall, not a monsoon
signal at all (see `rajshahi_aman_method_comparison.json`). Han et al.'s method
moves every single year's detected onset into the **May–June** window, which is climatologically the
correct season for monsoon onset in Bangladesh. This is a large, real improvement in face validity, not
a marginal one.

## Where this is uncertain, not just confirmed

1. **Residual boundary clustering.** 28% of years (7/25) land within 3 days of the search-window's own
   start date (May 15). This is a materially smaller boundary effect than the earlier, fully-saturated
   failure (17/25–25/25 years landing at the window edge under the earlier ad hoc search-window
   attempts), but it is not zero, and it means a meaningful minority of years may still be reflecting
   "whatever qualifies first once May 15 arrives" rather than a genuine, distinguishable monsoon
   transition for that specific year.
2. **The paper's own predicted failure mode did not clearly appear.** Han et al. explicitly caution
   that Rajshahi's LDS=6 parameter, being longer than the other three stations, "could be considered
   too strict... generating late onsets and increasing risk exposure due to early withdrawal of
   monsoon in Rajshahi" — i.e. they worried about **over-rejection producing late or missing onsets**.
   Mukti's NASA POWER result shows the **opposite pattern**: zero missing years, and a fair number of
   comparatively early (mid-to-late May) onsets. Two explanations are both plausible and neither is
   confirmed:
   - NASA POWER's ~50km grid-cell rainfall is a spatial average, which can smooth out the sharp,
     fully-dry days a point gauge would record, making a "true" dry spell less likely to read as fully
     dry (≤1mm) at grid resolution — this would systematically *reduce* false-onset rejections
     compared to the paper's station-based analysis.
   - Rajshahi's actual 2001–2025 rainfall pattern may simply differ from its 1981–2017 pattern in a
     way unrelated to the data-source difference.
   This project does not have enough independent evidence (e.g., a BMD Rajshahi series for the same
   2001–2025 period) to distinguish between these explanations here.
3. **No independent validation performed in this phase.** No NDVI/phenology cross-check (Task 9 of the
   `nasa_dataset_strategy_audit.md`'s own recommendation) has been run against these corrected onset
   dates. The plausibility judgment here rests on face validity (the dates now fall in the
   climatologically correct season) and internal consistency (the rejection logic is demonstrably
   active), not on an external check against observed transplanting or green-up dates.

## Classification

**METHOD_DATASET_TRANSFER_UNCERTAIN**

Justification: the method is correctly implemented (11/11 unit tests pass against hand-verified
synthetic cases) and produces a *qualitatively* correct result against real data — onset dates moved
from a demonstrably wrong season (Feb–Apr) into the climatologically correct one (May–June), with the
false-onset rejection logic visibly functioning. This is a genuine, substantial improvement over
`usable_rain_v1` and is not classified as failed. However, the residual boundary clustering (28% of
years) and the fact that the paper's own predicted Rajshahi failure mode (over-rejection/late onsets)
does not clearly manifest in this transfer are both unresolved, undiagnosed discrepancies between the
paper's context and Mukti's data source. Per this phase's own Task 21 criteria, this genuine
uncertainty means **decision_enabled must remain False** — scientific abstention, not a forced
enablement, is the correct outcome here.

## Recommendation for what would resolve the uncertainty (not undertaken in this phase)

- Obtain even a short, independent BMD-station or high-resolution gridded (e.g. a properly verified,
  version-current GPM IMERG or ENACTS-BMD) rainfall series for Rajshahi over an overlapping period, to
  check whether the false-onset rejection rate and onset-date spread are consistent with NASA POWER's.
- Cross-check a handful of the Han-method onset years against MCD12Q2 phenology `Greenup` dates for the
  pilot's coordinate, as a real-world signal independent of both rainfall data sources.
- Both are explicitly deferred — no new dataset was added in this phase, per its own scope rule.

## Phase 4A.2c — Independent Recomputation & Deterministic Validation Gate

This phase's task was to either resolve the two open uncertainties above or explicitly accept them
under a documented, deterministic policy. It did the latter. Nothing below was copied from the
Phase 4A.2b findings recorded earlier in this document — every number was independently recomputed
directly from the raw committed NASA POWER fixture (same SHA-256
`47a2fb929709a7732f64dad395b070bb222c6d1d959ef915398938a81cffb713`) by
`scripts/validate_han_transfer.py`, using the pure functions in `app/compute/monsoon_onset.py` and
the new `app/compute/han_validation.py`. See `demo_fixtures/analysis/rajshahi_aman_han_2024_validation.json`
for the full machine-readable artifact this section summarizes.

### What was recomputed, and whether it matched the earlier finding

- **Yearly onset dates, medians, shift, Mann-Whitney test**: independently rederived from the raw
  per-year onset results (not from this document). Result: reference median DOY 144.0, recent median
  DOY 138, `shift_days = -6.0`, Mann-Whitney U=37.5, p≈0.0293, 0 no-onset years, 9 false-onset
  rejections total — **exactly matching** the Phase 4A.2b figures above. This is expected, not a
  coincidence: both computations run the exact same pure algorithm against the exact same fixture, so
  an exact match is a reproducibility check passing, not new independent evidence that the method is
  correct. No discrepancy was found, so no root-cause investigation was needed.
- **Boundary clustering, independently recomputed at 1/2/3/5/7 days from the search-window start**
  (Task 15 — previously only the 3-day figure had been reported):

  | Boundary (days) | Years within boundary | Found years | Percentage |
  |---|---|---|---|
  | 1 | 5 | 25 | 20.0% |
  | 2 | 7 | 25 | 28.0% |
  | 3 | 7 | 25 | 28.0% |
  | 5 | 11 | 25 | 44.0% |
  | 7 | 13 | 25 | 52.0% |

  The 3-day figure (28.0%, 7/25) exactly matches Phase 4A.2b's own finding. The new 1/2/5/7-day figures
  show the clustering is not a narrow artifact of exactly the 3-day cutoff: it grows steadily as the
  boundary widens (20% → 28% → 44% → 52%), which is consistent with a real, gradual concentration of
  onset dates near the window start, not a coincidence of one particular boundary choice.

### Predefined parameter-sensitivity perturbations (Task 16/17)

Eight transparent, predefined perturbations of the published Rajshahi parameters were run — `lws_days`
and `lds_days` each ±1 day, `aws_mm` and `ads_mm` each ±20% — never tuned toward any desired outcome.
`lds_days` was specifically included in both directions because Han et al. (2024) themselves flag
Rajshahi's fitted LDS=6 as possibly "too strict." Every perturbed run used a `HanOnsetParameters` whose
`station_name` is suffixed `_sensitivity_<parameter>` (e.g. `Rajshahi_sensitivity_lds_days`) so it can
never be confused with the published Rajshahi configuration in code, logs, or the artifact — see the
`SENSITIVITY_EXPERIMENT_NOT_PUBLISHED_HAN_CONFIGURATION` labels in the JSON artifact.

Across all eight perturbations, the sign of `shift_days` (recent vs. reference) stayed negative
(earlier onset in recent years) in every case that produced a result — the direction is stable under
these parameter perturbations. This is a genuine, disclosed sensitivity finding beyond what Phase 4A.2b
reported (that phase's own sensitivity analysis varied `usable_rain_v1`'s rainfall threshold, not any
Han-method parameter).

### Independent validation evidence (Task 18/19/28)

**Status: not available.** This phase looked for a genuinely independent evidence source (a BMD
station series, or an MCD12Q2 phenology cross-check) at `demo_fixtures/independent_evidence/` — the
directory does not exist in this repository, and none was newly acquired in this phase. Per this
phase's own scope rule, fabricating, extrapolating, or approximating such evidence is forbidden, so
this is reported honestly as `insufficient_evidence` rather than papered over with the internal
diagnostics above (which, on their own, cannot distinguish a correct transfer from a coincidentally
plausible one — see the two open uncertainties from Phase 4A.2b, neither of which internal
recomputation alone can resolve).

### Deterministic validation classification

`app/compute/han_validation.py::classify_han_transfer_validation` applies one fixed rule (see that
module's docstring): no independent evidence available → `insufficient_evidence`, unconditionally,
regardless of how clean the boundary-clustering/sensitivity diagnostics otherwise look. Given this
phase's findings above:

- **`validation_status = "insufficient_evidence"`**
- **Reason codes**: `["no_independent_evidence_source_available"]`

This status is now computed fresh on every live `POST /api/v1/advisory/pilots/rajshahi-aman` request
(`AdvisoryService.compute_pilot_planting_window`, Phase 4A.2c) and exposed as
`han_method.validation_status` / `han_method.validation_reason_codes`, rather than being a hand-written
constant as in Phase 4A.2b. The legacy `han_method.transfer_review_classification` field is preserved
for backward compatibility, derived from `validation_status` (`insufficient_evidence` maps to
`METHOD_DATASET_TRANSFER_UNCERTAIN`, the same label Phase 4A.2b already used).

### `decision_enabled`

**Remains `False`.** The service now also computes an `effective_decision_enabled` value
(`pilot.decision_enabled AND validation_status == "validated"`) so that even if the static
`pilot.decision_enabled` flag were ever accidentally flipped without a genuine review, the live
response could still not produce an actionable recommendation while `validation_status` is anything
other than `validated`. This phase's own evidence (`insufficient_evidence`) does not satisfy that
condition, so no code path in this phase enables a farmer-facing recommendation.

### Remaining scientific limitation

Exactly as before: this project has no access mechanism, during the review, to acquire a BMD Rajshahi
station series or an MCD12Q2 phenology series. Until one is committed under
`demo_fixtures/independent_evidence/` (or an equivalent verified source), `validation_status` will
remain `insufficient_evidence` no matter how many additional internal sensitivity checks are run
against NASA POWER alone — internal consistency checks cannot substitute for an evidence source
genuinely independent of the one being validated. Per this phase's own explicit acceptance,
`insufficient_evidence` is treated as a successful, honest outcome of this phase, not a failure to fix.
