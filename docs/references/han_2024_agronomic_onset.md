# Han et al. (2024) Agronomic Monsoon-Onset Method — Source Record

This document is the single source of truth for the Han et al. (2024) monsoon-onset methodology as
implemented in `backend/api/app/compute/monsoon_onset.py`. Every fact below marked **PAPER FACT** was
independently verified by fetching and reading the paper's full text. Every fact marked
**MUKTI IMPLEMENTATION CHOICE** is this
project's own decision where the paper's prose leaves an implementation detail underspecified, and is
never to be read back as something the paper itself specifies.

## Citation (PAPER FACT)

Han, E., Montes, C., Hussain, S.G., & Krupnik, T.J. (2024). "Agronomic monsoon onset definitions to
support planting decisions for rainfed rice in Bangladesh." *Climatic Change*, 177(5), Article 77.
DOI: [10.1007/s10584-024-03736-z](https://doi.org/10.1007/s10584-024-03736-z). Open-access full text:
https://pmc.ncbi.nlm.nih.gov/articles/PMC11090806/. Published 13 May 2024.

## Study locations, data, and period (PAPER FACT)

- Four Bangladesh Meteorological Department (BMD) weather stations across a north-south gradient:
  **Barishal, Jashore, Rajshahi, Dinajpur**.
- Daily observations: rainfall, min/max temperature, sunshine hours, relative humidity, wind speed.
- Period: **1981–2017** (36 years).
- Rajshahi is explicitly described as **"comparatively the driest of the four study locations."**

## The onset algorithm (PAPER FACT, verbatim)

> "Monsoon onset date is defined as the first wet day from May 15th of the first wet spell of LWS
> days receiving at least the amount of rainfall AWS, without being followed by dry spell of LDS days
> receiving less rainfall than ADS in the subsequent 20 days from the onset."

Four station-fitted parameters:

- **LWS** — Length of the initial Wet Spell (consecutive days)
- **AWS** — cumulative rainfall (mm) required during that wet spell
- **LDS** — Length of a post-onset Dry Spell (consecutive days) that would disqualify the onset as false
- **ADS** — the rainfall ceiling (mm) for that dry spell to count as disqualifying

Wet/dry day thresholds (PAPER FACT, verbatim): **wet day = rainfall ≥ 1 mm; dry day = rainfall ≤ 1
mm.** (Note: a day at exactly 1.0mm satisfies both conditions as literally stated — the paper does not
resolve this overlap, and neither does this implementation; see "Mukti implementation choices" below.)

Search period (PAPER FACT): **May 15 – October 31**.

### Table 1 — station-fitted parameters (PAPER FACT, verified against the published table)

| Station | LWS (days) | AWS (mm) | LDS (days) | ADS (mm) |
|---|---|---|---|---|
| Barishal | 4 | 55 | 5 | 19 |
| Jashore | 3 | 27 | 5 | 17 |
| **Rajshahi** | **3** | **31** | **6** | **11** |
| Dinajpur | 3 | 34 | 6 | 12 |

**Rajshahi's parameters are the only ones Mukti uses** (`app/modules/advisory/pilots/rajshahi_aman.py`).

## Dynamic 1 vs Dynamic 2 (PAPER FACT)

- **Dynamic 1**: a simpler rule — nursery preparation triggered once accumulated rainfall over any 3
  consecutive days within the May 15–Aug 15 nursery-sowing window reaches ≥50mm. The paper reports this
  simpler rule "risk[s] giving rise to 'false starts' of the monsoon during the pre-monsoon season."
- **Dynamic 2**: the full agronomic definition above (LWS/AWS/LDS/ADS, per-station, with the false-onset
  dry-spell check). **This is the definition Mukti implements** (`han_agronomic_onset_v1`), because it
  is the one designed specifically to reject the pre-monsoon false starts that Mukti's own real NASA
  POWER analysis independently ran into.

## How the paper evaluated these definitions (PAPER FACT — corrected from an earlier, imprecise
characterization in this project's own prior audit note)

The paper's primary evaluation is **DSSAT CERES-Rice crop-model simulation**, not a direct comparison
against observed farm yields. They ran the crop model over the full 36-year (1981–2017) BMD weather
record for all four locations under each of the four onset-definition scenarios (a fixed calendar
date, Dynamic 1, Dynamic 2, and one more), producing a *distribution* of simulated yields per
scenario per location. They separately checked model plausibility against **one year (2015)** of
Bangladesh Integrated Household Survey (BIHS) field-survey data. **This is a plausibility check on
one year of survey data, not a multi-year, direct yield-validation study** — this project's earlier
audit note (`nasa_dataset_strategy_audit.md`) described this more loosely as "validated... via
crop-model simulation" and should be read with this correction: it is a simulated-yield comparison
across onset-definition scenarios, corroborated once against survey data, not a direct empirical
validation across years.

The paper's headline result for Dynamic 2: *"Average simulated yields increase up to 7–9%... over the
two drier locations [Jashore and Rajshahi]"* — this is a **simulated** yield benefit under the crop
model, not a measured field-yield benefit.

## The Rajshahi-specific caution (PAPER FACT, verbatim — must never be hidden)

> "This indicates that the agronomic onset definition parameters in Table 1, particularly six days of
> a post-onset dry spell could be considered as too strict to Rajshahi which has a relatively drier
> climate, generating late onsets and increasing risk exposure due to early withdrawal of monsoon in
> Rajshahi."

The paper itself flags that Rajshahi's own fitted LDS=6 parameter may over-reject valid onsets in a
dry climate, producing artificially late (or missing) onset dates. **This caveat is carried forward
into Mukti's own diagnostics** (`docs/references/han_2024_nasa_power_transfer_review.md`) rather than
silently adopted as if it were unproblematic.

## Data-source transfer: BMD gauge data vs NASA POWER grid (MUKTI IMPLEMENTATION CHOICE)

The paper fits and evaluates these parameters against **BMD ground-station daily observations**, not
NASA POWER's ~0.5°×0.625° gridded/model-blended product. Mukti applies the paper's *Rajshahi-fitted
parameters* to a *different data source* (NASA POWER `PRECTOTCORR`) than the one they were fitted on.
This is a defensible, disclosed analytical choice — the algorithm itself is data-source-agnostic — but
it is **not** the same as re-fitting the parameters against NASA POWER data, and no claim of exact
equivalence is made. See the transfer-review document for how this is assessed.

## Mukti implementation choices (NOT paper facts — decisions made where the paper's prose is silent)

1. **"Subsequent 20 days from the onset" window boundary**: the paper does not spell out whether the
   20-day look-ahead window starts at the onset day itself (offset 0) or the day after. Mukti's
   `han_agronomic_onset_v1` treats the window as **the 20 days starting at the onset date itself**
   (offsets 0–19 inclusive), and searches within that window for any run of `LDS` consecutive days
   (each satisfying the dry-day threshold) whose cumulative rainfall is below `ADS`. This is
   documented, not asserted as the one true reading of the paper.
2. **Wet/dry day overlap at exactly 1.0mm**: the paper's own thresholds (wet ≥1mm, dry ≤1mm) overlap
   at exactly 1.0mm. Mukti's implementation preserves this overlap literally rather than "fixing" it
   to a stricter mutually-exclusive rule, and is explicitly tested at this boundary
   (`tests/test_monsoon_onset.py`).
3. **Candidate search granularity**: candidates are evaluated at daily resolution, moving forward one
   day at a time when a candidate is rejected — consistent with how Mukti's existing `find_rainfall_onset`
   already searches, and with the paper's "first wet day... of the first wet spell" phrasing.
4. **Missing-data handling**: any wet-spell or post-onset-check window containing a day with no
   observation is never silently treated as 0mm; see `app/compute/monsoon_onset.py` for the explicit
   `missing_data` status this produces (Task 6 requirement).
5. **BMD-vs-NASA-POWER transfer**: applying station-fitted BMD parameters to NASA POWER grid data is
   Mukti's choice, disclosed above and in the transfer-review document — never presented as something
   the paper itself endorses.
