# AgriGuardian: Dual-Track Master Plan (Hackathon + Research Paper)

**As of 14 November 2026.** This plan separates implemented and recorded evidence from unvalidated claims. It does not assert that winning or paper acceptance is guaranteed.

## One research story

**Research question:** Can transparent, constraint-aware crop-rotation ranking using NASA climate context, BAMIS crop calendars and FAO suitability evidence be made safe, explainable and useful across Bangladesh's diverse regions?

**Core prototype:** Choose district or field, irrigation access and an outcome priority; compare feasible 2- and 3-crop sequences; inspect evidence, data scale, unknown water requirements and exclusions. Do not display a fake yield, profit, confidence score or future rainfall forecast.

### Current repository evidence

- 64 district references and regional BAMIS crop calendars are implemented; the all-district tests check centroid resolution, **not** independent farm-level recommendation quality.
- A deterministic crop-rotation engine uses calendar overlap, BAMIS water requirements, GAEZ suitability and the supported priorities; **NASA POWER climatology and SoilGrids are contextual outputs, not ranking signals** as of this plan.
- `docs/evidence/rotation_live_runs.json` contains **20 recorded cases (10 locations x two irrigation settings)**. These are stored scenario outputs, not verified farmer decisions.
- `docs/evidence/dataset_matrix.md` records **30 catalogued sources/products**. The recorded acquisition report has 4 ACQUIRED samples, 19 DISCOVERED metadata-only products, 6 NOT_CHECKED, and 1 NO_DATA. These are distinct evidence states.
- The Rajshahi monsoon-onset method has unresolved cross-product and independent validation questions. The advisory safety gate must remain on.
- The Flutter repository has typed rotation repositories/providers, but a live end-to-end public demo journey is not established by this plan.

## Hackathon track — 14–15 November 2026

**First: a truthful, 30-second story.** The challenge explicitly asks for a decision-support tool using NASA Earth observations with soil information, crop characteristics and farmer priorities. Judges look for impact, creativity, scientific validity, relevance and presentation.

### P0 before submission

1. Validate one complete user journey on an Android device from farmer inputs to backend rotation comparison and a visible source/uncertainty panel. Record screen capture; if authentication prevents public reviewer access, use a **publicly accessible recorded demonstration** rather than claiming a live open demo.
2. Demonstrate two real location cases (e.g. Rajshahi and Sylhet), with **actual location-specific outputs**, one irrigation scenario switch and the reason a crop was excluded. Avoid screenshots with demo labels masquerading as live readings.
3. Run `python backend/api/scripts/rotation_research_audit.py --output docs/evidence/rotation_research_audit.json`; inspect the status counts and unknown-water cases. Explain honestly that this is a reproducibility/snapshot audit, **not measured impact**.
4. Show NASA POWER provenance (parameter, historical period, grid resolution and original NASA URL). Do not imply NASA POWER temperatures/rainfall drive the current rotation ranking when they only provide context.
5. Verify the final demo link and GitHub/project link in an anonymous browser. Produce **at most 30 seconds of video OR up to seven slides**, and make the required short demo the primary submission asset.
6. Record AI-assisted work, older code, third-party data, external imagery, team contributions, and any explicit event organizer authorization for reusing existing work. Check 2026 rules; do not assume that a prior approval covers every reuse case.
7. Submit on the official team Project page by **15 November 2026, 11:59 PM local event time**. A GitHub push is not the submission.

### P1 if P0 is stable

- Add a clear bilingual feature walkthrough: farmer preference -> season options -> why selected -> missing data and caveats.
- Add a comparison panel for no irrigation vs full irrigation, **without implying one scenario is universally superior**.
- Export or screenshot the same source-linked claims to give judges a clear evidence trail.

### P2 after submission

- Improve offline UX, caching, async resilience and accessibility.
- Conduct real interviews and external agronomist review before making benefit claims.

## Research-paper track — after the hackathon

### Proposed paper (working title)

**AgriGuardian: An Evidence-Transparent, Uncertainty-Aware Crop Rotation Decision-Support Framework for Bangladesh**

Avoid claiming "multi-source fusion significantly improves yield" until that claim is measured against independent labels or field evidence.

### Scientific work packages

1. **Literature / novelty**: map prior crop rotation decision-support, agronomic feasibility constraints, explainability, uncertainty and geospatial evaluation. Write explicit novelty differences.
2. **Dataset manifest**: freeze versions, time windows, geographic resolution, original provider links, missing/fill-value logic, licenses and SHA-256 checksums. Do not treat discovery as acquisition.
3. **Causal relevance**: specify which variables actively change ranking. Test whether adding climate/soil improves measured expert agreement; if not, report the negative result.
4. **Baselines**: compare (A) calendar-only feasibility, (B) calendar plus GAEZ, (C) carefully justified climate/soil extension, (D) same extension with safety-abstention.
5. **Ground truth**: collect independent agronomist or farmer-reviewed acceptable rotations; include dissent and reviewers' expertise. Historical observed field outcomes are an even stronger but separate source.
6. **Evaluation**: expert top-1/top-3 agreement on viable cases; decision coverage; recommendations when experts find no safe option; constraint-violation counts; evidence provenance completeness; sensitivity to irrigation, region and year.
7. **Spatial/temporal generalization**: hold out entire districts or spatial regions and future seasons; do not use the same farm/year in train and test. For rule systems, test generalization across independent cases rather than describing it as learned-model CV.
8. **Uncertainty**: explicit abstention, missing evidence, map scale mismatch, near-border districts and disputed BAMIS calendars. Do not invent numeric confidence.
9. **Reproducibility**: frozen benchmark input, audit JSON, exact scripts, tests, dependency versions, DOI citations, honest limitations and paper figures.

### Research pass/fail gates

- PASS: at least one independently reviewed benchmark with a documented sampling protocol; otherwise label results *prototype only*.
- PASS: ablation isolates the contribution of each actual ranking input; if a source is only contextual, never call it a ranking improvement.
- PASS: no unverified accuracy, yield, profit, emissions, soil-health or water savings claims.
- PASS: no source/observation is counted as acquired without evidence; no unauthorized personal or location data enters public fixtures.
- PASS: clearly report what was measured, what was only demonstrated, and what remains unknown.

## Exact commands

From repository root:

```bash
python backend/api/scripts/rotation_research_audit.py --output docs/evidence/rotation_research_audit.json
cd backend/api
python -m pytest -q tests/test_rotation_research_audit.py
```

After *independent* reviews are collected:

```bash
python backend/api/scripts/rotation_research_audit.py --expert-reviews docs/research/reviews_private.json --output docs/evidence/expert_audit.json
```

Do not commit private consent forms or identifiable farmer-level data.

## Sources

- NASA challenge: https://www.spaceappschallenge.org/2026/challenges/field-shift-adapting-farms-with-nasa-data/
- NASA 2026 date/submission: https://www.spaceappschallenge.org/2026/
- NASA submission guidance: https://www.spaceappschallenge.org/resources/project-submission-guide
- Independent spatial transferability motivation: https://doi.org/10.1016/j.jafr.2024.101096
- Geospatial evaluation caveats: https://doi.org/10.1038/S41467-024-55240-8
- Local evidence: ../evidence/dataset_matrix.md, ../evidence/rotation_live_runs.json
