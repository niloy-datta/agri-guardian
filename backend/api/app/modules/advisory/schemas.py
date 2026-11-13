"""Request/response contracts for the NASA POWER planting-window advisory.

Every assumption that changes the computed result is an explicit input
field here - there is no hidden default hiding inside `crop_code` or
anywhere else. See `app/compute/agro.py` for what each field feeds into.
"""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field, model_validator


class PlantingWindowRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    # The full span of NASA POWER evidence to retrieve. Must cover both
    # the reference and recent periods below.
    start_year: int = Field(default=2001, ge=1981, le=2100)
    end_year: int = Field(default=2025, ge=1981, le=2100)

    reference_start_year: int = Field(default=2001, ge=1981, le=2100)
    reference_end_year: int = Field(default=2012, ge=1981, le=2100)
    recent_start_year: int = Field(default=2013, ge=1981, le=2100)
    recent_end_year: int = Field(default=2025, ge=1981, le=2100)

    # The usable-rain onset definition (`app/compute/agro.py`
    # `OnsetDefinition`). Defaults match the NASA Space Apps "Field Shift"
    # challenge guide, but every one is overridable - the response always
    # echoes back the definition actually used.
    rain_window_days: int = Field(default=7, ge=1, le=60)
    rain_threshold_mm: float = Field(default=20.0, ge=0.0)
    dry_spell_max_days: int = Field(default=7, ge=0, le=60)

    # Growing-degree-day base temperature. Required, no default: this is
    # an agronomic assumption this phase does not validate for any
    # specific crop, so the caller must state it explicitly.
    base_temperature_c: float

    # A label only. It is never used to look up or inject any agronomic
    # constant in this phase - see TASK 14 in the phase brief.
    crop_code: str | None = Field(default=None, max_length=64)

    @model_validator(mode="after")
    def _check_period_ordering(self) -> PlantingWindowRequest:
        if self.start_year > self.end_year:
            raise ValueError("start_year must be <= end_year")
        if self.reference_start_year > self.reference_end_year:
            raise ValueError("reference_start_year must be <= reference_end_year")
        if self.recent_start_year > self.recent_end_year:
            raise ValueError("recent_start_year must be <= recent_end_year")
        if self.reference_start_year < self.start_year or self.reference_end_year > self.end_year:
            raise ValueError("reference period must fall within start_year..end_year")
        if self.recent_start_year < self.start_year or self.recent_end_year > self.end_year:
            raise ValueError("recent period must fall within start_year..end_year")
        return self


class PeriodOut(BaseModel):
    start_year: int
    end_year: int


class OnsetDefinitionOut(BaseModel):
    window_days: int
    threshold_mm: float
    dry_spell_max_days: int


class SensitivityPointOut(BaseModel):
    threshold_mm: float
    shift_days: float | None
    reference_median_onset_doy: float | None
    recent_median_onset_doy: float | None
    data_status: str


class GddSummaryOut(BaseModel):
    base_temperature_c: float
    cumulative_gdd_c: float
    days_with_data: int
    days_missing: int


class ProvenanceOut(BaseModel):
    provider: str
    dataset_id: str
    source_url: str
    endpoint: str
    community: str
    parameters: list[str]
    latitude: float
    longitude: float
    start_date: date
    end_date: date
    time_standard: str
    retrieved_at: datetime
    units: dict[str, str]
    data_mode: str


class PlantingWindowResponse(BaseModel):
    # 'ok', or 'insufficient_reference_data' / 'insufficient_recent_data'
    # when a period does not have enough qualifying years for a median.
    # Never silently substitutes a number when this is not 'ok'.
    data_status: str

    reference_period: PeriodOut
    recent_period: PeriodOut
    onset_definition: OnsetDefinitionOut

    reference_onset_days: list[int]
    recent_onset_days: list[int]
    reference_median_onset_doy: float | None
    recent_median_onset_doy: float | None
    shift_days: float | None
    """recent_median - reference_median. Positive = later onset in the
    recent period; negative = earlier. Null when data_status != 'ok'."""

    mann_whitney_u: float | None
    p_value: float | None
    """A two-sided Mann-Whitney U test result describing whether the two
    periods' onset-day distributions differ under this test. Not a causal
    claim, and not converted into a plain-language "proof" of anything."""

    sensitivity: list[SensitivityPointOut]
    gdd_summary: GddSummaryOut

    assumptions: list[str]
    """Every scientific assumption behind this response, in plain text -
    the onset definition, the GDD base temperature, and the two periods
    compared."""
    provenance: ProvenanceOut
    warnings: list[str]


# ============================================================
# Rajshahi Aman pilot
# ============================================================


class PilotBaselineWindowOut(BaseModel):
    window_type: str
    start_month_day: tuple[int, int]
    end_month_day: tuple[int, int]


class PilotRecommendedWindowOut(BaseModel):
    start: date
    end: date


class EvidenceIntegrityOut(BaseModel):
    data_mode: str
    """'live', 'cache', or 'fixture' - see `NasaPowerProvenance.data_mode`."""
    verified: bool
    """True unless a fixture reached the response without passing manifest
    checksum verification - which `NasaPowerCache` never allows; this
    field exists so the check is visible on the wire, not just enforced
    silently server-side."""
    fixture_sha256: str | None = None
    local_evidence_path: str | None = None


class PilotSourceReferenceOut(BaseModel):
    title: str
    organization: str
    url: str
    accessed: str
    claim: str


class HanMethodOut(BaseModel):
    """The Han et al. (2024) `han_agronomic_onset_v1` method's own
    computed result, kept entirely separate from `applied_shift_days` -
    see Task 17 in the Phase 4A.2b brief and `docs/references/
    han_2024_nasa_power_transfer_review.md`. This is a computed climate
    statistic, not a farmer instruction, regardless of its values."""

    method_id: str
    method_source_doi: str
    computed_climate_shift_days: float | None
    """`recent_median - reference_median` under the Han method. Never
    rounded or applied to any date - see `applied_shift_days` on the
    parent response for the (currently always-null-while-gated) value
    that would ever reach a farmer-facing date."""
    reference_median_onset_doy: float | None
    recent_median_onset_doy: float | None
    mann_whitney_u: float | None
    p_value: float | None
    data_status: str
    decision_enabled: bool
    methodology_validated_for_mukti: bool
    agronomic_link_validated: bool
    transfer_review_classification: str
    """See `docs/references/han_2024_nasa_power_transfer_review.md` -
    'METHOD_REPRODUCED_PLAUSIBLY', 'METHOD_DATASET_TRANSFER_UNCERTAIN', or
    'METHOD_FAILED_DIAGNOSTICS'. Kept for backward compatibility; derived
    from `validation_status` (Phase 4A.2c), not an independent value."""
    validation_status: str
    """Phase 4A.2c's deterministic validation gate
    (`app/compute/han_validation.py::classify_han_transfer_validation`) -
    always exactly one of 'validated', 'transfer_uncertain', 'invalidated',
    'insufficient_evidence'. Computed fresh from this response's own
    boundary-clustering and sensitivity results on every request - never a
    hand-written constant."""
    validation_reason_codes: list[str]
    """Machine-readable reasons behind `validation_status` - never an
    arbitrary confidence percentage."""


class PilotPlantingWindowResponse(BaseModel):
    pilot_id: str
    location_name_bn: str
    crop_name_bn: str

    recommendation_status: str
    """'actionable', 'no_shift_supported', 'sensitivity_unstable', or
    'methodology_unvalidated' - see `app/compute/planting_policy.py`.
    Forced to 'methodology_unvalidated' whenever the pilot's
    `decision_enabled` flag is False, regardless of what the underlying
    comparison would otherwise support - see `han_method.decision_enabled`
    and Task 16 in the Phase 4A.2b brief."""

    headline_bn: str
    headline_en: str
    sms_bn: str

    baseline_window: PilotBaselineWindowOut
    recommended_window: PilotRecommendedWindowOut | None
    """Always None while `recommendation_status == 'methodology_unvalidated'`."""
    applied_shift_days: int | None
    """Always None while `recommendation_status == 'methodology_unvalidated'`
    - a real computed shift may still be visible in
    `computed_climate_shift_days` and `han_method.computed_climate_shift_days`."""
    computed_climate_shift_days: float | None
    """The `usable_rain_v1` method's raw computed shift (unrounded, not
    applied to any date) - present even while the recommendation is
    blocked, per Task 17. See `han_method` for the newer method's own
    computed shift."""

    reference_median_onset_doy: float | None
    recent_median_onset_doy: float | None
    mann_whitney_u: float | None
    p_value: float | None
    sensitivity: list[SensitivityPointOut]

    han_method: HanMethodOut

    assumptions: list[str]
    warnings: list[str]
    provenance: ProvenanceOut
    evidence_integrity: EvidenceIntegrityOut
    source_references: list[PilotSourceReferenceOut]


class PilotPlantingWindowRequest(BaseModel):
    """Deliberately almost empty: every scientific assumption is
    backend-controlled and sourced (`app/modules/advisory/pilots/
    rajshahi_aman.py`). The client may not override latitude, longitude,
    base_temperature_c, or the baseline crop calendar - see Task 10 in
    the phase brief. `target_year` is accepted only as a genuine
    presentation choice, not a scientific input."""

    target_year: int | None = Field(default=None, ge=1981, le=2100)
