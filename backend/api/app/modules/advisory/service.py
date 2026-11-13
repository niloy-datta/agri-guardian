"""Planting-window advisory business logic.

This service retrieves NASA POWER evidence, calls the deterministic
functions in `app/compute/agro.py`, and assembles the response with
provenance and honest warnings. It does not duplicate any equation - see
`app/compute/__init__.py` for why that boundary exists - and it never
calls an LLM.
"""

from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING

from app.compute.agro import (
    GddResult,
    OnsetDefinition,
    compare_periods,
    compute_gdd_series,
    mann_whitney_shift_test,
    onset_day_of_year_by_year,
    sensitivity_analysis,
)
from app.compute.han_validation import (
    DEFAULT_BOUNDARY_DAYS,
    classify_han_transfer_validation,
    compute_boundary_clustering,
    default_rajshahi_sensitivity_perturbations,
    run_han_sensitivity_perturbations,
)
from app.compute.monsoon_onset import (
    METHOD_ID as HAN_METHOD_ID,
)
from app.compute.monsoon_onset import (
    METHOD_SOURCE_DOI as HAN_METHOD_SOURCE_DOI,
)
from app.compute.monsoon_onset import (
    HanOnsetParameters,
    compare_han_periods,
    han_onset_by_year,
)
from app.compute.planting_policy import (
    BaselineWindow,
    PlantingRecommendation,
    evaluate_planting_recommendation,
)
from app.integrations.nasa.client import PowerDailyRecord
from app.modules.advisory.pilots.rajshahi_aman import RajshahiAmanPilot
from app.modules.advisory.schemas import (
    EvidenceIntegrityOut,
    GddSummaryOut,
    HanMethodOut,
    OnsetDefinitionOut,
    PeriodOut,
    PilotBaselineWindowOut,
    PilotPlantingWindowResponse,
    PilotRecommendedWindowOut,
    PilotSourceReferenceOut,
    PlantingWindowRequest,
    PlantingWindowResponse,
    ProvenanceOut,
    SensitivityPointOut,
)

_VALIDATION_STATUS_TO_LEGACY_CLASSIFICATION: dict[str, str] = {
    "validated": "METHOD_REPRODUCED_PLAUSIBLY",
    "transfer_uncertain": "METHOD_DATASET_TRANSFER_UNCERTAIN",
    "invalidated": "METHOD_FAILED_DIAGNOSTICS",
    "insufficient_evidence": "METHOD_DATASET_TRANSFER_UNCERTAIN",
}
"""Maps Phase 4A.2c's deterministic `validation_status`
(`app/compute/han_validation.py`) onto the legacy classification labels
`docs/references/han_2024_nasa_power_transfer_review.md` already used
(Phase 4A.2b). Kept only so `transfer_review_classification` does not
break any existing consumer; `validation_status` is the field a new
consumer should read."""

# No BMD station series or MCD12Q2 phenology data has been acquired for this
# cross-check, and none should be fabricated. See
# `scripts/validate_han_transfer.py`'s discovery check and
# docs/references/han_2024_nasa_power_transfer_review.md's
# Phase 4A.2c section. If a future phase commits such evidence under
# `demo_fixtures/independent_evidence/`, this flag (and the discovery
# logic it stands in for here) should be replaced with a real check.
HAN_INDEPENDENT_EVIDENCE_AVAILABLE = False

if TYPE_CHECKING:
    from app.integrations.nasa.power_cache import NasaPowerCache

SENSITIVITY_THRESHOLD_DELTA_MM = 5.0


class AdvisoryService:
    def __init__(self, *, cache: NasaPowerCache) -> None:
        self._cache = cache

    async def compute_planting_window(
        self, request: PlantingWindowRequest
    ) -> PlantingWindowResponse:
        warnings: list[str] = []

        evidence_start = date(request.start_year, 1, 1)
        evidence_end = date(request.end_year, 12, 31)

        lookup = await self._cache.get_daily_point(
            latitude=request.latitude,
            longitude=request.longitude,
            start=evidence_start,
            end=evidence_end,
        )
        response = lookup.response

        precip_by_year = self._group_by_year(
            response.records,
            field="precipitation_mm",
            start_year=request.start_year,
            end_year=request.end_year,
        )
        tmax_by_date = {record.date: record.tmax_c for record in response.records}
        tmin_by_date = {record.date: record.tmin_c for record in response.records}

        definition = OnsetDefinition(
            window_days=request.rain_window_days,
            threshold_mm=request.rain_threshold_mm,
            dry_spell_max_days=request.dry_spell_max_days,
        )
        onset_by_year = onset_day_of_year_by_year(precip_by_year, definition=definition)

        reference_years = range(request.reference_start_year, request.reference_end_year + 1)
        recent_years = range(request.recent_start_year, request.recent_end_year + 1)

        comparison = compare_periods(
            onset_by_year, reference_years=reference_years, recent_years=recent_years
        )
        mann_whitney = mann_whitney_shift_test(
            comparison.reference_onset_days, comparison.recent_onset_days
        )
        sensitivity = sensitivity_analysis(
            precip_by_year,
            base_definition=definition,
            reference_years=reference_years,
            recent_years=recent_years,
            threshold_delta_mm=SENSITIVITY_THRESHOLD_DELTA_MM,
        )
        gdd = compute_gdd_series(
            tmax_by_date, tmin_by_date, base_temperature_c=request.base_temperature_c
        )

        if comparison.data_status != "ok":
            warnings.append(
                f"Historical comparison incomplete: {comparison.data_status} "
                f"(reference years with onset: {len(comparison.reference_onset_days)}, "
                f"recent years with onset: {len(comparison.recent_onset_days)})."
            )
        if mann_whitney.data_status != "ok":
            warnings.append(
                "Mann-Whitney test not computed: insufficient onset samples in "
                "one or both periods."
            )
        if gdd.days_missing:
            warnings.append(
                f"{gdd.days_missing} day(s) in the requested range are missing "
                "temperature data; the cumulative GDD figure excludes them "
                "rather than treating them as zero-GDD days."
            )
        if lookup.source != "live":
            warnings.append(f"NASA POWER evidence served from {lookup.source}, not a live call.")

        assumptions = self._build_assumptions(request, definition, gdd)

        return PlantingWindowResponse(
            data_status=comparison.data_status,
            reference_period=PeriodOut(
                start_year=request.reference_start_year, end_year=request.reference_end_year
            ),
            recent_period=PeriodOut(
                start_year=request.recent_start_year, end_year=request.recent_end_year
            ),
            onset_definition=OnsetDefinitionOut(
                window_days=definition.window_days,
                threshold_mm=definition.threshold_mm,
                dry_spell_max_days=definition.dry_spell_max_days,
            ),
            reference_onset_days=comparison.reference_onset_days,
            recent_onset_days=comparison.recent_onset_days,
            reference_median_onset_doy=comparison.reference_median_onset_doy,
            recent_median_onset_doy=comparison.recent_median_onset_doy,
            shift_days=comparison.shift_days,
            mann_whitney_u=mann_whitney.u_statistic,
            p_value=mann_whitney.p_value,
            sensitivity=[
                SensitivityPointOut(
                    threshold_mm=point.threshold_mm,
                    shift_days=point.comparison.shift_days,
                    reference_median_onset_doy=point.comparison.reference_median_onset_doy,
                    recent_median_onset_doy=point.comparison.recent_median_onset_doy,
                    data_status=point.comparison.data_status,
                )
                for point in sensitivity.points
            ],
            gdd_summary=GddSummaryOut(
                base_temperature_c=gdd.base_temperature_c,
                cumulative_gdd_c=gdd.cumulative_gdd_c,
                days_with_data=gdd.days_with_data,
                days_missing=gdd.days_missing,
            ),
            assumptions=assumptions,
            provenance=ProvenanceOut(
                provider=response.provenance.provider,
                dataset_id=response.provenance.dataset_id,
                source_url=response.provenance.source_url,
                endpoint=response.provenance.endpoint,
                community=response.provenance.community,
                parameters=list(response.provenance.parameters),
                latitude=response.provenance.latitude,
                longitude=response.provenance.longitude,
                start_date=response.provenance.start_date,
                end_date=response.provenance.end_date,
                time_standard=response.provenance.time_standard,
                retrieved_at=response.provenance.retrieved_at,
                units=response.provenance.units,
                data_mode=response.provenance.data_mode,
            ),
            warnings=warnings,
        )

    @staticmethod
    def _group_by_year(
        records: list[PowerDailyRecord],
        *,
        field: str,
        start_year: int,
        end_year: int,
    ) -> dict[int, dict[date, float | None]]:
        grouped: dict[int, dict[date, float | None]] = {
            year: {} for year in range(start_year, end_year + 1)
        }
        for record in records:
            year = record.date.year
            if year in grouped:
                grouped[year][record.date] = getattr(record, field)
        return grouped

    @staticmethod
    def _build_assumptions(
        request: PlantingWindowRequest, definition: OnsetDefinition, gdd: GddResult
    ) -> list[str]:
        assumptions = [
            "MEASURED/COMPUTED, not an agronomic recommendation: this response "
            "reports a shift in a defined usable-rain onset statistic, not a "
            "validated planting instruction.",
            (
                f"Usable-rain onset definition: first {definition.window_days}-day "
                f"period with cumulative rainfall >= {definition.threshold_mm} mm, "
                f"not immediately followed by a fully dry spell of "
                f"{definition.dry_spell_max_days}+ consecutive days."
            ),
            (
                f"Reference period {request.reference_start_year}-"
                f"{request.reference_end_year} vs. recent period "
                f"{request.recent_start_year}-{request.recent_end_year}."
            ),
            (
                f"GDD base temperature {gdd.base_temperature_c} deg C: an "
                "explicit input for this request, not a validated crop-specific "
                "constant."
            ),
        ]
        if request.crop_code:
            assumptions.append(
                f"crop_code '{request.crop_code}' is a label only; it does not "
                "alter any computation in this response."
            )
        return assumptions

    # ============================================================
    # Rajshahi Aman pilot
    # ============================================================

    async def compute_pilot_planting_window(
        self, pilot: RajshahiAmanPilot
    ) -> PilotPlantingWindowResponse:
        """The pilot endpoint's only entry point. Every scientific
        assumption comes from `pilot` (backend-controlled, sourced in
        `docs/references/rajshahi_aman_pilot.md`) - nothing here accepts a
        client-supplied latitude, longitude, base temperature, or crop
        calendar. Reuses the exact same NASA-evidence-to-statistics
        pipeline as `compute_planting_window`; this method's own job is
        only the recommendation policy and the Bangla/English wording.
        """
        warnings: list[str] = []

        evidence_start = date(pilot.reference_start_year, 1, 1)
        evidence_end = date(pilot.recent_end_year, 12, 31)

        lookup = await self._cache.get_daily_point(
            latitude=pilot.latitude, longitude=pilot.longitude, start=evidence_start, end=evidence_end
        )
        response = lookup.response

        precip_by_year = self._group_by_year(
            response.records,
            field="precipitation_mm",
            start_year=pilot.reference_start_year,
            end_year=pilot.recent_end_year,
        )

        definition = OnsetDefinition(
            window_days=pilot.rain_window_days,
            threshold_mm=pilot.rain_threshold_mm,
            dry_spell_max_days=pilot.dry_spell_max_days,
        )
        onset_by_year = onset_day_of_year_by_year(precip_by_year, definition=definition)

        reference_years = range(pilot.reference_start_year, pilot.reference_end_year + 1)
        recent_years = range(pilot.recent_start_year, pilot.recent_end_year + 1)

        comparison = compare_periods(
            onset_by_year, reference_years=reference_years, recent_years=recent_years
        )
        mann_whitney = mann_whitney_shift_test(
            comparison.reference_onset_days, comparison.recent_onset_days
        )
        sensitivity = sensitivity_analysis(
            precip_by_year,
            base_definition=definition,
            reference_years=reference_years,
            recent_years=recent_years,
            threshold_delta_mm=SENSITIVITY_THRESHOLD_DELTA_MM,
        )

        if comparison.data_status != "ok":
            warnings.append(
                f"Historical comparison incomplete: {comparison.data_status} "
                f"(reference years with onset: {len(comparison.reference_onset_days)}, "
                f"recent years with onset: {len(comparison.recent_onset_days)})."
            )
        if mann_whitney.data_status != "ok":
            warnings.append(
                "Mann-Whitney test not computed: insufficient onset samples in "
                "one or both periods."
            )
        if not pilot.gdd_base_temperature_verified:
            warnings.append(
                "GDD base temperature is not independently primary-source-"
                "verified for this pilot; no GDD-based claim is presented "
                "(see docs/references/rajshahi_aman_pilot.md)."
            )
        if lookup.source != "live":
            warnings.append(f"NASA POWER evidence served from {lookup.source}, not a live call.")

        baseline_window = BaselineWindow(
            window_type=pilot.baseline_window_type,
            start_month_day=pilot.baseline_window_start_month_day,
            end_month_day=pilot.baseline_window_end_month_day,
        )
        raw_recommendation = evaluate_planting_recommendation(
            baseline_window=baseline_window, comparison=comparison, sensitivity=sensitivity
        )

        # ---- Han et al. (2024) method: computed alongside, never the
        # decision source while pilot.decision_enabled is False. See
        # docs/references/han_2024_nasa_power_transfer_review.md.
        han_parameters = HanOnsetParameters(
            station_name="Rajshahi",
            lws_days=pilot.han_lws_days,
            aws_mm=pilot.han_aws_mm,
            lds_days=pilot.han_lds_days,
            ads_mm=pilot.han_ads_mm,
            search_start_month_day=pilot.han_search_start_month_day,
            search_end_month_day=pilot.han_search_end_month_day,
            wet_day_threshold_mm=pilot.han_wet_day_threshold_mm,
            dry_day_threshold_mm=pilot.han_dry_day_threshold_mm,
            post_onset_lookahead_days=pilot.han_post_onset_lookahead_days,
        )
        han_onset_by_year_result = han_onset_by_year(precip_by_year, parameters=han_parameters)
        han_comparison = compare_han_periods(
            han_onset_by_year_result, reference_years=reference_years, recent_years=recent_years
        )
        han_mann_whitney = mann_whitney_shift_test(
            han_comparison.reference_onset_days, han_comparison.recent_onset_days
        )

        # ---- Phase 4A.2c: deterministic transfer-validation gate,
        # recomputed from this response's own evidence on every request -
        # never a hand-written classification string. See
        # app/compute/han_validation.py and docs/references/
        # han_2024_nasa_power_transfer_review.md's Phase 4A.2c section.
        han_boundary_clustering = compute_boundary_clustering(
            han_onset_by_year_result,
            search_start_month_day=pilot.han_search_start_month_day,
            boundary_days_list=DEFAULT_BOUNDARY_DAYS,
        )
        han_sensitivity_perturbations = default_rajshahi_sensitivity_perturbations(han_parameters)
        han_sensitivity_results = run_han_sensitivity_perturbations(
            precip_by_year,
            base_parameters=han_parameters,
            perturbations=han_sensitivity_perturbations,
            reference_years=reference_years,
            recent_years=recent_years,
        )
        han_validation = classify_han_transfer_validation(
            boundary_clustering=han_boundary_clustering,
            sensitivity_results=han_sensitivity_results,
            independent_evidence_available=HAN_INDEPENDENT_EVIDENCE_AVAILABLE,
        )
        # `pilot.decision_enabled` is a manually-reviewed, sourced flag
        # (see rajshahi_aman.py) - but it must never actually gate an
        # actionable recommendation unless this request's own freshly
        # computed validation status agrees it is "validated". This
        # defends against a future accidental flip of the static flag
        # outrunning a real review.
        effective_decision_enabled = pilot.decision_enabled and han_validation.status == "validated"
        han_transfer_classification = _VALIDATION_STATUS_TO_LEGACY_CLASSIFICATION[
            han_validation.status
        ]
        if not effective_decision_enabled:
            warnings.append(
                "Recommendation blocked: methodology_unvalidated. The Han et al. "
                "(2024) monsoon-onset method has been implemented and run against "
                "real NASA POWER evidence, but its transfer from BMD station data "
                "to NASA POWER grid data is classified as "
                f"{han_validation.status} ({', '.join(han_validation.reason_codes)}) - "
                "see docs/references/han_2024_nasa_power_transfer_review.md. No "
                "planting-date recommendation is active."
            )

        # ---- Recommendation safety gate (Task 16/17, Phase 4A.2b): a
        # scientifically unvalidated method must never produce an
        # actionable farmer-facing date, regardless of what the
        # comparison/sensitivity direction check alone would support.
        if effective_decision_enabled:
            recommendation = raw_recommendation
        else:
            recommendation = PlantingRecommendation(
                recommendation_status="methodology_unvalidated",
                baseline_window=baseline_window,
                recommended_window=None,
                applied_shift_days=None,
                reason_codes=["decision_not_enabled"],
            )

        assumptions = self._build_pilot_assumptions(pilot, definition)
        headline_bn, headline_en = self._build_pilot_headlines(pilot, recommendation)
        sms_bn = self._build_pilot_sms(recommendation)

        return PilotPlantingWindowResponse(
            pilot_id=pilot.pilot_id,
            location_name_bn=pilot.location_name_bn,
            crop_name_bn=pilot.crop_name_bn,
            recommendation_status=recommendation.recommendation_status,
            headline_bn=headline_bn,
            headline_en=headline_en,
            sms_bn=sms_bn,
            baseline_window=PilotBaselineWindowOut(
                window_type=baseline_window.window_type,
                start_month_day=baseline_window.start_month_day,
                end_month_day=baseline_window.end_month_day,
            ),
            recommended_window=(
                PilotRecommendedWindowOut(
                    start=recommendation.recommended_window.start,
                    end=recommendation.recommended_window.end,
                )
                if recommendation.recommended_window is not None
                else None
            ),
            applied_shift_days=recommendation.applied_shift_days,
            computed_climate_shift_days=comparison.shift_days,
            reference_median_onset_doy=comparison.reference_median_onset_doy,
            recent_median_onset_doy=comparison.recent_median_onset_doy,
            mann_whitney_u=mann_whitney.u_statistic,
            p_value=mann_whitney.p_value,
            sensitivity=[
                SensitivityPointOut(
                    threshold_mm=point.threshold_mm,
                    shift_days=point.comparison.shift_days,
                    reference_median_onset_doy=point.comparison.reference_median_onset_doy,
                    recent_median_onset_doy=point.comparison.recent_median_onset_doy,
                    data_status=point.comparison.data_status,
                )
                for point in sensitivity.points
            ],
            han_method=HanMethodOut(
                method_id=HAN_METHOD_ID,
                method_source_doi=HAN_METHOD_SOURCE_DOI,
                computed_climate_shift_days=han_comparison.shift_days,
                reference_median_onset_doy=han_comparison.reference_median_onset_doy,
                recent_median_onset_doy=han_comparison.recent_median_onset_doy,
                mann_whitney_u=han_mann_whitney.u_statistic,
                p_value=han_mann_whitney.p_value,
                data_status=han_comparison.data_status,
                decision_enabled=effective_decision_enabled,
                methodology_validated_for_mukti=pilot.methodology_validated_for_mukti,
                agronomic_link_validated=pilot.agronomic_link_validated,
                transfer_review_classification=han_transfer_classification,
                validation_status=han_validation.status,
                validation_reason_codes=han_validation.reason_codes,
            ),
            assumptions=assumptions,
            warnings=warnings,
            provenance=ProvenanceOut(
                provider=response.provenance.provider,
                dataset_id=response.provenance.dataset_id,
                source_url=response.provenance.source_url,
                endpoint=response.provenance.endpoint,
                community=response.provenance.community,
                parameters=list(response.provenance.parameters),
                latitude=response.provenance.latitude,
                longitude=response.provenance.longitude,
                start_date=response.provenance.start_date,
                end_date=response.provenance.end_date,
                time_standard=response.provenance.time_standard,
                retrieved_at=response.provenance.retrieved_at,
                units=response.provenance.units,
                data_mode=response.provenance.data_mode,
            ),
            evidence_integrity=EvidenceIntegrityOut(
                data_mode=response.provenance.data_mode,
                verified=(
                    response.provenance.data_mode != "fixture"
                    or response.provenance.fixture_sha256 is not None
                ),
                fixture_sha256=response.provenance.fixture_sha256,
                local_evidence_path=response.provenance.local_evidence_path,
            ),
            source_references=[
                PilotSourceReferenceOut(
                    title=ref.title,
                    organization=ref.organization,
                    url=ref.url,
                    accessed=ref.accessed,
                    claim=ref.claim,
                )
                for ref in pilot.source_references
            ],
        )

    @staticmethod
    def _build_pilot_assumptions(pilot: RajshahiAmanPilot, definition: OnsetDefinition) -> list[str]:
        return [
            "MEASURED/COMPUTED, not an agronomic recommendation on its own: "
            "NASA POWER provides climate evidence; Mukti computes this "
            "advisory by applying a sourced baseline calendar to it. NASA "
            "does not recommend a planting date.",
            (
                f"Usable-rain onset definition (Mukti's own analytical choice, "
                f"not attributed to any agronomy source): first "
                f"{definition.window_days}-day period with cumulative "
                f"rainfall >= {definition.threshold_mm} mm, not immediately "
                f"followed by a fully dry spell of "
                f"{definition.dry_spell_max_days}+ consecutive days."
            ),
            (
                f"Baseline {pilot.baseline_window_type} window: "
                f"{pilot.baseline_window_start_month_day} to "
                f"{pilot.baseline_window_end_month_day} (national Bangladesh "
                "figure, BRRI-hosted crop calendar sourced to BBS Year Book "
                "of Agricultural Statistics-2023; not Rajshahi-specific - "
                "see docs/references/rajshahi_aman_pilot.md)."
            ),
            (
                f"Reference period {pilot.reference_start_year}-"
                f"{pilot.reference_end_year} vs. recent period "
                f"{pilot.recent_start_year}-{pilot.recent_end_year}."
            ),
            (
                "Fractional day shifts are rounded to the nearest whole day, "
                "ties rounding away from zero."
            ),
            (
                f"Pilot coordinate {pilot.latitude}, {pilot.longitude}: "
                f"{pilot.coordinate_meaning}"
            ),
        ]

    @staticmethod
    def _build_pilot_headlines(
        pilot: RajshahiAmanPilot, recommendation: PlantingRecommendation
    ) -> tuple[str, str]:
        if recommendation.recommendation_status == "methodology_unvalidated":
            # Task 18 (Phase 4A.2b): never say "plant X days earlier/later"
            # while the recommendation is gated - a real computed shift may
            # still be visible via `computed_climate_shift_days` /
            # `han_method`, but it is never worded as an instruction here.
            return (
                "Han et al. (2024) পদ্ধতিতে NASA POWER বৃষ্টির তথ্য বিশ্লেষণ করা "
                "হয়েছে। কিন্তু এই ফলাফলকে আমন রোপণের তারিখ পরিবর্তনের পরামর্শ "
                "হিসেবে এখনো সক্রিয় করা হয়নি।",
                "NASA POWER rainfall data has been analyzed using the Han et "
                "al. (2024) monsoon-onset method. This result has not yet "
                "been activated as an Aman planting-date recommendation - "
                "see the transfer-review classification for why.",
            )

        if recommendation.recommendation_status == "actionable":
            # `evaluate_planting_recommendation` only sets this status
            # alongside a non-None window - see planting_policy.py.
            assert recommendation.recommended_window is not None
            shift = recommendation.applied_shift_days or 0
            direction_bn = "পরে" if shift > 0 else "আগে"
            direction_en = "later" if shift > 0 else "earlier"
            window = recommendation.recommended_window
            headline_bn = (
                f"NASA POWER-এর {pilot.recent_end_year - pilot.reference_start_year + 1} "
                f"বছরের তথ্য অনুযায়ী, ব্যবহারযোগ্য বৃষ্টির শুরু সাম্প্রতিক সময়ে প্রায় "
                f"{abs(shift)} দিন {direction_bn} হয়েছে। যাচাইকৃত আমন ক্যালেন্ডার "
                f"অনুযায়ী প্রস্তাবিত রোপণ উইন্ডো: {window.start.strftime('%d %b')}"
                f"–{window.end.strftime('%d %b')}।"
            )
            headline_en = (
                f"Per {pilot.recent_end_year - pilot.reference_start_year + 1} years of "
                f"NASA POWER data, usable-rain onset has shifted about {abs(shift)} days "
                f"{direction_en} in recent years. Applying the verified Aman calendar, "
                f"the suggested transplanting window is "
                f"{window.start.strftime('%d %b')}–{window.end.strftime('%d %b')}."
            )
            return headline_bn, headline_en

        if recommendation.recommendation_status == "sensitivity_unstable":
            return (
                "এই মৌসুমের বৃষ্টি-শুরুর প্রবণতা সংজ্ঞার উপর নির্ভরশীল এবং স্থিতিশীল নয়; "
                "নির্দিষ্ট রোপণ উইন্ডো এখনো নিশ্চিত করা যাচ্ছে না।",
                "The rainfall-onset trend for this pilot is sensitive to the "
                "onset definition and not stable across thresholds; a precise "
                "revised window is not yet supported.",
            )

        return (
            "এই মুহূর্তে পর্যাপ্ত NASA তথ্য না থাকায় নির্দিষ্ট পরামর্শ দেওয়া সম্ভব হচ্ছে না।",
            "Insufficient NASA evidence is currently available to support a "
            "specific recommendation.",
        )

    @staticmethod
    def _build_pilot_sms(recommendation: PlantingRecommendation) -> str:
        if recommendation.recommendation_status == "methodology_unvalidated":
            sms = (
                "মুক্তি: রাজশাহী আমন - NASA তথ্য বিশ্লেষণ করা হয়েছে, কিন্তু রোপণের "
                "তারিখ পরিবর্তনের পরামর্শ এখনো সক্রিয় করা হয়নি।"
            )
        elif recommendation.recommendation_status == "actionable":
            assert recommendation.recommended_window is not None
            window = recommendation.recommended_window
            sms = (
                f"মুক্তি: রাজশাহী আমন - NASA তথ্য অনুযায়ী বৃষ্টির শুরু "
                f"{abs(recommendation.applied_shift_days or 0)} দিন "
                f"{'পরে' if (recommendation.applied_shift_days or 0) > 0 else 'আগে'}। "
                f"প্রস্তাবিত রোপণ: {window.start.strftime('%d %b')}-"
                f"{window.end.strftime('%d %b')}।"
            )
        else:
            sms = (
                "মুক্তি: রাজশাহী আমন - বর্তমান NASA তথ্য পর্যাপ্ত/স্থিতিশীল না হওয়ায় "
                "নির্দিষ্ট রোপণ সময় জানানো সম্ভব হয়নি।"
            )
        # This project's chosen length rule: <= 160 Unicode characters.
        return sms[:160]
