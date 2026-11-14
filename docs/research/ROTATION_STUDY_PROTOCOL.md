# AgriGuardian Rotation Study — Pre-Registration Draft

**Status:** proposed research design. No independent expert agreement metrics or field outcome improvements have been measured in this document.

## Research questions

- RQ1: Are the rotation scenarios produced by a transparent calendar/water/suitability rule engine acceptable to independent local agronomic experts?
- RQ2: Does adding validated climate and soil factors change expert agreement or decision coverage relative to calendar-only and calendar+GAEZ baselines?
- RQ3: Does explicit abstention for missing evidence reduce unsafe proposals without unacceptably reducing coverage?
- RQ4: Are findings stable across held-out Bangladesh districts and cropping seasons?

## Unit of analysis and labels

One review unit = a specific **field/district + cropping season + irrigation availability + farmer priority set**. The same unit must be presented to multiple methods. Crop sequences preserve order, not just crop sets.

An independent reviewer should see the input conditions and candidate options without seeing the model name or rank where practical. Record acceptable sequences, whether no safe sequence is possible, and the reviewer disagreement process. Obtain appropriate informed consent and minimize personally identifying information.

**No invented labels.** Existing `docs/evidence/rotation_live_runs.json` is a recorded software snapshot, not an independent review dataset.

## Experimental methods

- A: district calendar feasibility baseline.
- B: calendar + GAEZ + BAMIS water feasibility (current engine, with a clearly versioned configuration).
- C: validated NASA rainfall/temperature and soil-informed *new algorithm*, only once appropriate spatial/temporal alignment, thresholds and tests exist.
- D: C + missingness/uncertainty abstention.

The application must not claim C or D are implemented until each has running code, unit tests and an independent measured result. Freeze dataset versions and model/rule settings before evaluating on the held-out cases.

## Primary endpoint and safety metrics

**Primary:** expert top-3 agreement on expert-viable cases, with 95% confidence intervals if sample size permits and sampling assumptions are documented.

**Secondary:** expert top-1 agreement, decision coverage, unsafe proposals when experts found no safe rotation, correct abstentions, explicit calendar/water constraint violations, ranking stability and complete source provenance.

Expert agreement is not equivalent to **yield prediction accuracy** or measured economic/environmental benefit.

Use paired comparisons on the same case IDs only. Do not compare unpaired model aggregates as if they were experimental differences. Report exact denominators and confidence intervals; choose statistical tests according to reviewer and sampling structure.

## Data provenance and leakage controls

For each provider: data version, product name, spatial resolution, temporal coverage, acquisition UTC time, file hash, source URL/DOI, terms of use, quality flags, coordinate interpretation and known errors.

Group holdouts by district/field and cropping season. Avoid pooling adjacent grid observations across train/test when model calibration uses geospatial inputs. For a deterministic rule-based method, label the analysis a *held-out scenario evaluation*, not ML model generalization unless a model has actually been trained.

## Repeatable audit

```bash
python backend/api/scripts/rotation_research_audit.py --output docs/evidence/rotation_research_audit.json
```

The report includes an SHA-256 for its input and emphasizes that it audits recorded scenarios, not verified field outcomes.

Once real expert annotations are recorded in a PRIVATE JSON file, run:

```bash
python backend/api/scripts/rotation_research_audit.py --expert-reviews path/to/private_review.json --output path/to/report.json
```

**Expected file schema:**

```json
{
  "schema_version": 1,
  "reviews": []
}
```

The empty template intentionally causes the evaluator to withhold metrics. Each future real review row must have:

- `case_id`: stable anonymized unit ID.
- `district`: documented district.
- `season`: e.g. calendar year/cropping season identifier.
- `model`: exact baseline/proposed variant.
- `recommended_rotations`: ordered list of crop-sequence arrays, or [] for abstention.
- `expert_acceptable_rotations`: externally assessed sequences, or [] if none is acceptable.

Use exactly one row per (`case_id`, `model`). Do not commit reviewer names, private farm coordinates, consent forms or raw identifiable farmer interviews.

## Figure/table checklist

1. Data-source provenance, scale and acquisition-status table.
2. Method flowchart and precisely specified rules.
3. Study-site and held-out district map with appropriate privacy protection.
4. Paired baseline table with all denominators and confidence intervals.
5. Source ablation chart: which actual feature changed which ranking.
6. Case-level uncertainty and abstention tradeoff.
7. Failure cases and external expert feedback.

## Reporting/acceptance rules

- No recorded scenario becomes "validated" without independent review or measured outcome.
- No synthetic unit test becomes an empirical result.
- No NASA or soil dataset is described as improving ranking while it remains context-only.
- No numerical performance improvement is stated until independently computed and reproducible.
- Report both failed and positive experiments, missingness and regional source discrepancies.

## Related methodological literature

- Habibi et al. (2024), independent spatial validation in agricultural modelling: https://doi.org/10.1016/j.jafr.2024.101096
- Geospatial validation caveats and spatial cross-validation: https://doi.org/10.1038/S41467-024-55240-8
