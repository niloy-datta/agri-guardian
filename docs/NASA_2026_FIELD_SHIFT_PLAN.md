# NASA Space Apps 2026 — Field Shift Challenge-Fit Plan

Phase **NASA-1** deliverable. Audit + architecture + integrity findings only — no
competition-specific solution code was written in this phase (see
[Competition-rule timing constraints](#competition-rule-timing-constraints) below for why).

## 1. Official challenge, verified live (2026-09-27)

- **Exact title, confirmed at the official URL**: *"Field Shift: Adapting Farms with
  NASA Data"* —
  `https://www.spaceappschallenge.org/2026/challenges/field-shift-adapting-farms-with-nasa-data/`
- **The full official challenge statement is NOT yet published.** As of today, only a
  short "Challenge Summary" list is live on `spaceappschallenge.org/2026/challenges/`;
  the page itself states full challenge statements/resources are scheduled for
  **October 28, 2026**. The page is a client-rendered app (Next.js), so its full text
  could not be scraped directly; the title above was confirmed via the canonical URL
  slug, independently corroborated by search-engine indexing of the same page.
- **Best-available description of scope** (assembled from public team submissions
  already built against this challenge on GitHub — third-party, not NASA text, and
  explicitly marked as such below): a decision-support tool combining NASA Earth
  observations, local soil information, crop characteristics, and farmer priorities to
  explore crop-rotation strategies that strengthen soil health and help farms adapt to
  changing conditions. Example team framings seen: "turn 25+ years of NASA Earth
  observations into ranked, explainable crop-rotation strategies... every number traces
  to a named dataset"; "combine NASA Earth Observation products with localized soil and
  seasonal calendars to evaluate candidate crop rotations against real-world
  environmental stress." **These are unofficial paraphrases of other teams' project
  descriptions, not the NASA challenge text.** They are directionally useful but must
  not be treated as requirements until the October 28 statement is read.
- A pre-existing untracked file already in this repo,
  `docs/references/nasa_bangladesh_agriculture_datasets_updated.md` (and a stray
  duplicate at the repo root — not yet committed either place), catalogs 61 candidate
  NASA/Copernicus datasets with per-variable "decision rules" (e.g. "Daily > 25mm
  indicates onset," "T > 35°C at flowering causes spikelet sterility"). The dataset
  names/resolutions/coverage in that table look like real product metadata, but the
  **decision-rule thresholds in column 5 carry no per-row citation** — per this
  project's own rule against inventing agronomic thresholds, none of those thresholds
  should be used in NASA-2/3 until each is traced to a specific primary source. This
  file is flagged, not deleted or endorsed.

## 2. Competition-rule timing constraints

Verified live against `spaceappschallenge.org` and search results, not from memory:

- **Event dates**: November 14–15, 2026. Project submission opens Nov 14, 9:00 AM and
  closes Nov 15, 11:59 PM (local time).
- **Full challenge resources**: scheduled for release **October 28, 2026**. Today
  (2026-09-27) is before that date.
- **Pre-event work rule** (verified): teams may research the challenge and look at data
  early, but **all actual project assets and code must be created during the 48-hour
  event window**, and any pre-existing tools/libraries used must be disclosed.
- **Implication for this repo**: Mukti already has substantial pre-existing NASA
  infrastructure (POWER client/cache, Han onset method, offline fixture architecture)
  built across Phases 3–4A.2c, well before Oct 28 or Nov 14. That is legitimate
  *pre-existing tooling* under the disclosed-tools rule, **not** the Field Shift
  solution itself. Per this rule and per `CONTRIBUTING.md`'s "do not implement future phases
  early," **Phases NASA-2 through NASA-5 (the actual rotation-decision solution, its
  evidence layer, its Flutter UX, and the final seal) must not be built now.** The
  earliest either could legitimately start is Oct 28 (once real requirements exist to
  build against, not invented ones), and the disclosed-pre-existing-tools rule means the
  actual challenge-specific code should be attributed to the Nov 14–15 window.
- This phase (NASA-1) is limited to audit, integrity cleanup of already-existing fake
  data, and planning/documentation — which the rule explicitly permits before the event.

## 3. Repository pre-flight (verified via git, not assumed)

- Review-start local `HEAD`: `bbd97e2` ("feat: add marketplace mobile client").
- Expected prior commit `712f3e4` ("Phase 4A.2c") — **confirmed present locally**, not
  missing (the initial scope check passed).
- Local was **2 commits ahead of `origin/main`** (`712f3e4`, `bbd97e2`) at session
  start — a clean ahead-state, not a diverged history. No reset/force-push was used;
  this was left for the user to push explicitly.
- **During the review, a concurrent commit landed and was pushed to `origin/main` outside
  the review**: `351e383` ("feat: add GPM IMERG precipitation cross-validation
  scaffold (Phase 4B.1, blocked)"), authored by the repo owner, timestamped
  2026-09-27 23:30 +0600. Local and remote are now both at `351e383` (0 ahead / 0
  behind) — this phase's own base commit.
- **Security note (unrelated to Field Shift, flagged to the user directly in-session,
  not fixed here)**: `git remote -v` shows a GitHub personal access token embedded in
  plaintext in the `origin` URL. Not touched or logged further in this document beyond
  this note; the user was told directly to revoke/rotate it.
- **Pre-existing, unrelated CI failure** (not caused by this phase, not fixed by this
  phase — out of NASA-1's scope): Flutter CI fails on `lib/features/marketplace/...`
  (`create_listing_screen.dart:145`, undefined type `MarketplaceRepositoryException` in
  a catch clause; also one unused-import warning in `marketplace_providers.dart`).
  Confirmed locally with `flutter analyze --no-fatal-infos`. Marketplace is explicitly
  out of scope for the Field Shift competition path per this project's own architecture
  rule below.

## 4. Critical integrity audit — fake data findings

### 4a. The four named files — confirmed fake, confirmed dead, **removed in this phase**

`lib/features/satellite/data/{nasa_gpm_api,hls_api,nasadem_api,sentinel_api}.dart` each
returned a single hard-coded literal regardless of the `lat`/`lng` arguments passed in
(e.g. `nasa_gpm_api.dart` always returned `38.5`; `hls_api.dart` always returned
`{'ndvi': 0.74, 'ndwi': 0.32, 'evi': 0.61}`). Grepping the entire repository confirmed
**no other file ever imported or instantiated any of the four classes** — they were
unreachable dead code, not wired into any screen, provider, or route.

Per this phase's explicit instruction to remove/quarantine/replace such paths, and
since deleting unreferenced dead code carries no functional risk, **all four files were
deleted** (`git rm`). Nothing else in the tree referenced them, so no other file needed
changing.

### 4b. A worse, *reachable* finding, discovered independently (not on the original suspect list)

`lib/screens/satellite_map.dart` (`SatelliteMapScreen`) **is directly navigated to** from
`lib/screens/home.dart:581` and `lib/screens/field_insights.dart:446` (`Navigator.push`,
bypassing `go_router` entirely — it's also separately registered as the
`/satellite-analysis` `go_router` route, though nothing currently navigates through that
path). This screen is real, polished, reachable UI, and **100% of its "satellite
intelligence" is static, hard-coded UI content, not fed by any API or backend call**:

- A fixed "72%" circular health gauge (`value: 0.72`, literal).
- A static `'Sentinel-2'` badge with no corresponding data source.
- Static literal text `'GPS: 24.4332° N, 90.7812° E'`.
- Static literal Bangla text claiming a "সর্বশেষ স্যাটেলাইট পাস" (latest satellite pass)
  "today at 6:15am."
- Three static "detected issues" cards (blast-disease suspicion, waterlogging,
  "normal growth density") with no backing evidence, presented with alert badges as if
  they were live findings.

This is a materially bigger integrity risk than the four dead files, because it is the
one a judge or farmer would actually see. **It was deliberately not modified in this
phase** — rewriting reachable production UI is a bigger change than "quarantine four
unused files," is not on this phase's allowed-file list, and fixing it properly requires
real backend evidence that does not exist yet (that's NASA-3/4 territory). It is
recorded here as the **single highest-priority blocker** before any NASA-4 (Flutter UX)
work, and arguably before any public demo of the app at all, competition or not.

`lib/features/satellite/presentation/screens/satellite_analysis_screen.dart` is a third,
harmless dead file (never routed to by `router.dart`, which points `/satellite-analysis`
at `SatelliteMapScreen` instead — confirmed by `router.dart`'s own comment that
`lib/features/**` stubs were superseded by `lib/screens/**`). It shows only static
Bangla label text, no fabricated numbers. Left untouched; not worth the churn.

## 5. Challenge-fit matrix

| Field Shift requirement | Repo state | Evidence |
|---|---|---|
| NASA Earth observations | **Partially implemented** | Real NASA POWER (precipitation, T2M) client + cache + SHA-256-verified fixture for one Rajshahi point (Phase 4A.1/4A.2a). GPM IMERG client exists but is explicitly `BLOCKED` — verified live against real GES DISC endpoints, but no real data acquired (no Earthdata Login credential in this environment; Phase 4B.1 correctly refused to fabricate a fixture). |
| Local soil information | **Missing** | No soil data model, schema, or input contract exists anywhere in the backend. |
| Crop characteristics | **Missing** | No versioned crop-characteristics evidence model exists. |
| Farmer priorities | **Missing** | No structured priority input (water/soil/climate/diversity/risk) exists anywhere. |
| Crop-rotation exploration | **Missing** | Zero rotation-scenario code. The only advisory logic in the repo is a single-crop (Aman rice) planting-window shift analysis for one pilot coordinate — not rotation. |
| Soil-health implications | **Missing** | No soil-health computation exists. |
| Water considerations | **Partially implemented** | Precipitation evidence exists (NASA POWER); no water-demand/irrigation modeling connects it to a decision. |
| Climate adaptation | **Partially implemented** | Han et al. (2024) agronomic monsoon-onset shift analysis exists and is real, but gated `insufficient_evidence` / `decision_enabled=False` — a correctly honest non-recommendation, not yet a usable adaptation decision. |
| Explainability | **Implemented (pattern), not yet applied to rotation** | The advisory module already has a strong provenance/validation-status/reason-code pattern (`SourceReference`, `validation_status`, `han_method.*`) worth reusing verbatim for NASA-2/3's evidence model. |
| Usable farmer decision | **Unsafe/fake in the reachable satellite screen; correctly absent (not fabricated) in the real advisory pilot** | See §4b for the fake screen. The real pilot endpoint (`POST /api/v1/advisory/pilots/rajshahi-aman`) correctly returns `recommendation_status: "methodology_unvalidated"` and nulls out any actionable date rather than inventing one — good behavior, but it means **zero actionable farmer decisions exist in the repo today**, let alone a rotation one. |
| Unrelated to Field Shift | Marketplace/bidding (Phase 12A), AI assistant screen, plant-scan diagnosis flow | Real, working features, but out of this competition story per the architecture rule below. Not touched in this phase. |

**Conclusion, stated plainly per this phase's own instruction not to pretend otherwise:**
the existing planting-window advisory work is real, honest, and scientifically careful,
but it is a single-crop planting-date analysis, not crop-rotation decision support. It
can become supporting climate context for Field Shift; it is not itself the solution.

## 6. Architecture decision (narrowest fit, locked)

```
NASA evidence (POWER; IMERG once unblocked)
   -> local soil + crop context (new, strictly sourced or `insufficient_soil_evidence`)
   -> farmer priorities (new, explicit farmer-selected weights, no hidden defaults)
   -> rotation scenario computation (new, pure/deterministic, MEASURED vs SOURCE-DERIVED
      vs COMPUTED vs USER-SELECTED vs NOT ESTABLISHED, per input)
   -> transparent trade-offs (reuse the existing provenance/validation-status pattern)
   -> Bangla/mobile farmer presentation (new; must replace, not add to, the fake
      satellite screen)
```

This does **not** turn Mukti into a generic dashboard, does not add marketplace scope,
and does not add generic chatbot functionality.

## 7. Retained components (real, keep building on these)

- `NasaPowerClient` / `NasaPowerCache` (`backend/api/app/integrations/nasa/`) —
  provenance, offline fixture, SHA-256 manifest integrity. Reuse as-is for whatever
  evidence NASA-3 actually needs.
- `app/compute/agro.py`, `monsoon_onset.py`, `han_validation.py` — pure, deterministic,
  well-tested. The Han et al. (2024) onset-shift analysis can become rotation *climate
  context*, not a rotation score, per this phase's own instruction not to force it.
- Phase 4A.2c's validation-gate pattern (`validation_status`,
  `effective_decision_enabled = pilot.decision_enabled AND validation_status ==
  "validated"`) — this is exactly the abstention discipline NASA-2 needs for
  `insufficient_soil_evidence` / `insufficient_evidence` states. Reuse the pattern, not
  the pilot-specific code.
- Phase 4B.1's honest-block behavior (`imerg_client.py`) — real product verified, no
  fake fixture substituted. Same discipline should apply to any new soil/crop dataset.
- Offline-first cache/sync architecture (Phase 3) — reusable for the Flutter side of a
  future rotation explorer.

## 8. Excluded from the competition demo

- Marketplace/bidding (Phase 12A) and its Flutter client.
- The generic AI-assistant screen.
- The plant-scan/diagnosis flow (unrelated disease-ID feature).
- The fake satellite screens identified in §4 (dead files removed; `satellite_map.dart`
  flagged for replacement, not deletion, once real evidence exists).

## 9. Required new components (not built in this phase)

1. Local-soil input contract (`insufficient_soil_evidence` on missing data; no
   coordinate-derived fabrication).
2. Versioned crop-characteristics evidence model (source, version, units, provenance,
   applicability region, confidence per field).
3. Structured farmer-priority input (explicit weights, no hidden defaults).
4. Rotation scenario model + pure deterministic comparison engine (ordered crop
   sequence over a planning horizon; MEASURED/SOURCE-DERIVED/COMPUTED/USER-SELECTED/NOT
   ESTABLISHED separation).
5. A rotation comparison API endpoint, authenticated, ownership-checked.
6. A Flutter rotation-explorer flow (Field → Priorities → Options → Compare → Evidence →
   Decision Summary) that replaces the fake satellite screen rather than sitting next to
   it.

## 10. Remaining roadmap (not started)

- **NASA-2** — Deterministic Crop Rotation Scenario Engine (soil/crop/priority
  contracts + pure comparison functions + API). Blocked until at least Oct 28 per §2.
- **NASA-3** — Real NASA Evidence Expansion + Reproducible Offline Demo (choose the
  smallest evidence set the rotation engine's own decision variables actually need;
  finish or formally retire the GPM IMERG Earthdata-auth blocker; delete/quarantine
  `satellite_map.dart`'s fake content as part of "Flutter must receive normalized
  evidence only through Mukti's backend contract").
- **NASA-4** — Bangla-first rotation explorer UX + evidence storytelling (replaces
  `satellite_map.dart`'s fake screen with the real thing).
- **NASA-5** — Competition readiness seal (fake-data re-scan, README, demo script,
  judge Q&A, submission checklist).

## 11. Data-source questions waiting for the October 28 resources

- Which specific NASA products does the *official* Field Shift resource list actually
  recommend (vs. the 61-dataset catalog already sitting in this repo, which is
  unofficial and has unsourced thresholds — see §1)?
- Does the official challenge provide or point to a soil-data source usable for
  Bangladesh (SoilGrids? a national soil survey?), or is local-soil input expected to be
  farmer-entered?
- Will GPM IMERG (or any Earthdata-Login-gated product) be practically acquirable
  during the 48-hour event, or should the rotation engine be designed to work with
  NASA POWER alone plus whatever the official resources newly unlock?
- What does the official judging rubric weight, so NASA-4's "judge understands in under
  one minute" goal is aimed at the right thing?

## 12. What NASA-1 verified vs. did not

Verified this phase, by actually running the command (not assumed):
- `git rev-parse HEAD`, `git status --short`, `git branch -vv`, `git log`, `git fetch
  origin main`, `git rev-list --left-right --count` — all in §3.
- `flutter analyze --no-fatal-infos` (baseline, before and after the file deletions in
  §4a) — 1 pre-existing error + 1 pre-existing warning, both in the untouched
  marketplace feature; 176 pre-existing info-level findings; zero new issues introduced by this phase's own
  changes.
- Live web verification of the Field Shift challenge title/URL, the Nov 14–15, 2026
  event dates, the Oct 28, 2026 resource-release date, and the "code must be created
  during the 48-hour window, pre-existing tools must be disclosed" rule.
- `gh run list` / `gh run view --log-failed` — confirmed the pre-existing Flutter CI
  failure's exact cause and that it is unrelated to this phase's changes.

Not run this phase, disclosed rather than silently skipped:
- `ruff check .` / `mypy app` — **could not be run**; neither tool is installed in this
  local environment's Python (no system Python on `PATH`; the project's own `backend/api/.venv`
  has no `ruff`/`mypy` module installed either). Backend Python files were not modified
  in this phase, so this is a verification gap, not a regression risk, but it is an
  honest gap, not a claimed pass.
- `pytest` — not run; no backend files changed in this phase, so not attempted.
- No official Field Shift full statement exists yet to check requirements against
  (§1) — the challenge-fit matrix in §5 is therefore the review's best-effort read of
  the *existing repo* against the *challenge summary*, not against verified official
  requirements.
