"""Phase 4A.2c — deterministic Han/NASA-POWER transfer validation gate.

Pure deterministic Python only - no FastAPI, no HTTP, no database, no LLM
(see `app/compute/__init__.py`'s package boundary). This module does not
recompute the Han onset algorithm itself (`app/compute/monsoon_onset.py`
already owns that) - it only (a) independently re-derives boundary-
clustering diagnostics and predefined parameter-sensitivity results from
an already-computed `HanOnsetResult` mapping, and (b) applies one fixed,
documented decision rule that turns those diagnostics plus an
independent-evidence-availability flag into one of exactly four
validation statuses.

Why a separate module from `monsoon_onset.py`: that module is the paper's
algorithm, verbatim. This module is Mukti's own validation *policy* layer
on top of it - the same separation `planting_policy.py` already keeps
from `agro.py`. Nothing here is attributed to Han et al. (2024) - the
boundary/sensitivity thresholds below are this project's own disclosed
analytical choices, not paper facts.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field, replace
from datetime import date
from typing import Any, Literal

from app.compute.agro import MannWhitneyResult, PeriodComparisonResult, mann_whitney_shift_test
from app.compute.monsoon_onset import (
    HanOnsetParameters,
    HanOnsetResult,
    compare_han_periods,
    han_onset_by_year,
)

ValidationStatus = Literal["validated", "transfer_uncertain", "invalidated", "insufficient_evidence"]

DEFAULT_BOUNDARY_DAYS = (1, 2, 3, 5, 7)
"""Distances (days) from the search-window start date at which residual
boundary clustering is measured - Task 15 of the Phase 4A.2c brief asks
for exactly these five values."""

BOUNDARY_GATE_DAYS = 3
"""Which of `DEFAULT_BOUNDARY_DAYS` the validation decision rule below
actually gates on - matches the boundary distance the Phase 4A.2b
transfer review already used for its own "28% of years" finding, so the
gate is measuring the same thing that review flagged, not a new goalpost."""

BOUNDARY_PCT_THRESHOLD = 25.0
"""Above this percentage of found-onset years landing within
`BOUNDARY_GATE_DAYS` of the search-window start, the transfer is treated
as still showing a meaningful boundary artifact. This project's own
disclosed threshold - not sourced from Han et al. (2024) - chosen because
the Phase 4A.2b finding (28%, 7/25) is the concrete instance this gate
must classify as still uncertain, not as resolved by rounding."""


@dataclass(frozen=True, slots=True)
class BoundaryClusterPoint:
    boundary_days: int
    years_within_boundary: list[int]
    found_year_count: int
    """Years with a found onset in the evaluated set - the denominator.
    Never confused with the total year count, since a no-onset year has
    no distance-from-boundary to measure."""
    percentage: float | None
    """`None` only when `found_year_count == 0` - a percentage of zero
    years is undefined, not 0.0."""


def compute_boundary_clustering(
    onset_by_year: Mapping[int, HanOnsetResult],
    *,
    search_start_month_day: tuple[int, int],
    boundary_days_list: Sequence[int] = DEFAULT_BOUNDARY_DAYS,
) -> list[BoundaryClusterPoint]:
    """For each requested boundary distance, counts how many found-onset
    years landed within that many days of the search window's own start
    date for that year. Re-derives this from the raw per-year onset
    dates on every call - it is never copied from a documentation string.
    """
    found_years: dict[int, date] = {
        year: result.onset_date
        for year, result in onset_by_year.items()
        if result.found and result.onset_date is not None
    }
    points: list[BoundaryClusterPoint] = []
    for boundary_days in boundary_days_list:
        within = sorted(
            year
            for year, onset_date in found_years.items()
            if (onset_date - date(year, *search_start_month_day)).days <= boundary_days
        )
        found_count = len(found_years)
        percentage = (len(within) / found_count * 100.0) if found_count > 0 else None
        points.append(
            BoundaryClusterPoint(
                boundary_days=boundary_days,
                years_within_boundary=within,
                found_year_count=found_count,
                percentage=percentage,
            )
        )
    return points


@dataclass(frozen=True, slots=True)
class SensitivityPerturbation:
    """One transparent, predefined parameter perturbation. `parameter_name`
    must name an actual `HanOnsetParameters` field - see
    `default_rajshahi_sensitivity_perturbations`."""

    parameter_name: str
    original_value: float | int
    changed_value: float | int
    reason: str


@dataclass(frozen=True, slots=True)
class HanSensitivityRunResult:
    perturbation: SensitivityPerturbation
    comparison: PeriodComparisonResult
    mann_whitney: MannWhitneyResult
    no_onset_year_count: int
    false_onset_candidates_rejected_total: int


def default_rajshahi_sensitivity_perturbations(
    base: HanOnsetParameters,
) -> list[SensitivityPerturbation]:
    """This project's own predefined, transparent perturbations of the
    published Rajshahi Table 1 parameters - never tuned to produce a
    desired classification (Phase 4A.2c Task 16/17). `lds_days` is
    perturbed both directions by 1 day specifically because Han et al.
    (2024) themselves flag Rajshahi's LDS=6 as possibly "too strict" -
    see docs/references/han_2024_agronomic_onset.md - so this is the one
    parameter with a documented reason to suspect fragility, not an
    arbitrary choice.
    """
    return [
        SensitivityPerturbation(
            parameter_name="lws_days",
            original_value=base.lws_days,
            changed_value=base.lws_days + 1,
            reason="+1 day on the initial wet-spell length, to check whether the "
            "onset date is sensitive to a small change in how long the wet "
            "spell must persist.",
        ),
        SensitivityPerturbation(
            parameter_name="lws_days",
            original_value=base.lws_days,
            changed_value=max(base.lws_days - 1, 1),
            reason="-1 day on the initial wet-spell length (floored at 1), the "
            "mirror-image perturbation of the +1 day case above.",
        ),
        SensitivityPerturbation(
            parameter_name="aws_mm",
            original_value=base.aws_mm,
            changed_value=round(base.aws_mm * 1.2, 2),
            reason="+20% on the wet-spell cumulative rainfall requirement, to "
            "check sensitivity to the rainfall-amount threshold rather than "
            "only the day-count thresholds.",
        ),
        SensitivityPerturbation(
            parameter_name="aws_mm",
            original_value=base.aws_mm,
            changed_value=round(base.aws_mm * 0.8, 2),
            reason="-20% on the wet-spell cumulative rainfall requirement, the "
            "mirror-image perturbation of the +20% case above.",
        ),
        SensitivityPerturbation(
            parameter_name="lds_days",
            original_value=base.lds_days,
            changed_value=base.lds_days + 1,
            reason="+1 day on the post-onset false-start dry-spell length. Han "
            "et al. (2024) themselves caution Rajshahi's fitted LDS=6 may be "
            "too strict; this checks whether making it stricter still "
            "changes the result materially.",
        ),
        SensitivityPerturbation(
            parameter_name="lds_days",
            original_value=base.lds_days,
            changed_value=max(base.lds_days - 1, 1),
            reason="-1 day on the post-onset false-start dry-spell length - "
            "directly probes the paper's own flagged over-rejection concern "
            "by relaxing the parameter it named.",
        ),
        SensitivityPerturbation(
            parameter_name="ads_mm",
            original_value=base.ads_mm,
            changed_value=round(base.ads_mm * 1.2, 2),
            reason="+20% on the false-start dry-spell rainfall ceiling.",
        ),
        SensitivityPerturbation(
            parameter_name="ads_mm",
            original_value=base.ads_mm,
            changed_value=round(base.ads_mm * 0.8, 2),
            reason="-20% on the false-start dry-spell rainfall ceiling, the "
            "mirror-image perturbation of the +20% case above.",
        ),
    ]


def _perturbed_parameters(
    base: HanOnsetParameters, perturbation: SensitivityPerturbation
) -> HanOnsetParameters:
    """Returns a NEW `HanOnsetParameters` with exactly one field changed -
    `base` (the published, production configuration) is never mutated;
    `HanOnsetParameters` is frozen, so mutation is not even possible. The
    perturbed copy's `station_name` is always suffixed so it can never be
    mistaken for the published Rajshahi configuration in any downstream
    label, log line, or artifact (Phase 4A.2c Task 17)."""
    field_change: dict[str, Any] = {perturbation.parameter_name: perturbation.changed_value}
    changed = replace(base, **field_change)
    return replace(
        changed,
        station_name=f"{base.station_name}_sensitivity_{perturbation.parameter_name}",
    )


def run_han_sensitivity_perturbations(
    daily_precip_by_year: Mapping[int, Mapping[date, float | None]],
    *,
    base_parameters: HanOnsetParameters,
    perturbations: Sequence[SensitivityPerturbation],
    reference_years: Sequence[int],
    recent_years: Sequence[int],
) -> list[HanSensitivityRunResult]:
    """Re-runs the full Han onset -> period-comparison pipeline once per
    perturbation. Never reuses or mutates a result computed under
    `base_parameters` - each perturbation gets its own independent run."""
    results: list[HanSensitivityRunResult] = []
    for perturbation in perturbations:
        parameters = _perturbed_parameters(base_parameters, perturbation)
        onset_by_year = han_onset_by_year(daily_precip_by_year, parameters=parameters)
        comparison = compare_han_periods(
            onset_by_year, reference_years=reference_years, recent_years=recent_years
        )
        mann_whitney = mann_whitney_shift_test(
            comparison.reference_onset_days, comparison.recent_onset_days
        )
        results.append(
            HanSensitivityRunResult(
                perturbation=perturbation,
                comparison=comparison,
                mann_whitney=mann_whitney,
                no_onset_year_count=sum(1 for r in onset_by_year.values() if not r.found),
                false_onset_candidates_rejected_total=sum(
                    r.false_onset_candidates_rejected for r in onset_by_year.values()
                ),
            )
        )
    return results


def _sensitivity_shift_signs(sensitivity_results: Sequence[HanSensitivityRunResult]) -> set[int]:
    signs: set[int] = set()
    for run in sensitivity_results:
        if run.comparison.data_status != "ok" or run.comparison.shift_days is None:
            continue
        if run.comparison.shift_days > 0:
            signs.add(1)
        elif run.comparison.shift_days < 0:
            signs.add(-1)
        else:
            signs.add(0)
    return signs


@dataclass(frozen=True, slots=True)
class HanValidationResult:
    status: ValidationStatus
    reason_codes: list[str] = field(default_factory=list)


def classify_han_transfer_validation(
    *,
    boundary_clustering: Sequence[BoundaryClusterPoint],
    sensitivity_results: Sequence[HanSensitivityRunResult],
    independent_evidence_available: bool,
    boundary_gate_days: int = BOUNDARY_GATE_DAYS,
    boundary_pct_threshold: float = BOUNDARY_PCT_THRESHOLD,
) -> HanValidationResult:
    """One fixed, documented decision rule. Deterministic: identical
    inputs always produce an identical `HanValidationResult` - there is
    no randomness, wall-clock read, or external call anywhere in this
    function.

    Rule, in order:
    1. No independent evidence source -> `insufficient_evidence`. Without
       an evidence source genuinely independent of NASA POWER itself
       (e.g. a BMD station series, or an MCD12Q2 phenology cross-check),
       this project cannot distinguish a correct transfer from a
       coincidentally plausible one - see Phase 4A.2c's own scope rule
       that fabricating or extrapolating such evidence is forbidden.
    2. Independent evidence available but sensitivity disagrees on shift
       direction across the predefined perturbations -> `transfer_uncertain`.
    3. Independent evidence available but boundary clustering at
       `boundary_gate_days` still exceeds `boundary_pct_threshold`
       -> `transfer_uncertain`.
    4. Otherwise -> `validated`.

    `invalidated` is reserved for a case this function cannot reach on
    its own: independent evidence that directly contradicts the method's
    onset dates. That comparison is not implemented in this phase (no
    independent evidence source exists to contradict anything against);
    a future phase that adds one must extend this function rather than
    inferring `invalidated` from proxies.
    """
    reason_codes: list[str] = []

    if not independent_evidence_available:
        reason_codes.append("no_independent_evidence_source_available")
        return HanValidationResult(status="insufficient_evidence", reason_codes=reason_codes)

    shift_signs = _sensitivity_shift_signs(sensitivity_results)
    if len(shift_signs) > 1:
        reason_codes.append("sensitivity_direction_contradictory")
        return HanValidationResult(status="transfer_uncertain", reason_codes=reason_codes)

    gate_point = next(
        (point for point in boundary_clustering if point.boundary_days == boundary_gate_days),
        None,
    )
    if gate_point is None:
        reason_codes.append("boundary_gate_distance_not_computed")
        return HanValidationResult(status="transfer_uncertain", reason_codes=reason_codes)

    if gate_point.percentage is not None and gate_point.percentage > boundary_pct_threshold:
        reason_codes.append(
            f"boundary_clustering_at_{boundary_gate_days}d_exceeds_{boundary_pct_threshold}pct"
        )
        return HanValidationResult(status="transfer_uncertain", reason_codes=reason_codes)

    reason_codes.append("sensitivity_direction_consistent")
    reason_codes.append(f"boundary_clustering_at_{boundary_gate_days}d_within_threshold")
    return HanValidationResult(status="validated", reason_codes=reason_codes)
