"""Tests for the Rajshahi Aman pilot's real NASA evidence + analysis
pipeline (Phase 4A.2a). These exercise the actual committed fixture in
`demo_fixtures/nasa_power/` and the actual analysis artifact in
`demo_fixtures/analysis/` - not synthetic stand-ins - because the point of
this phase is to prove the real evidence chain, end to end.

`test_power_cache.py` already covers `NasaPowerCache`'s integrity/
provenance behavior with synthetic fixtures; this file covers what is
specific to the pilot: its sourced config, its real committed evidence,
and its analysis artifact.
"""

from __future__ import annotations

import ast
import asyncio
import json
from pathlib import Path

import httpx
import pytest

from app.integrations.nasa.client import DEFAULT_PARAMETERS, NasaPowerClient
from app.integrations.nasa.power_cache import (
    NasaEvidenceIntegrityError,
    NasaPowerCache,
    canonical_cache_key,
)
from app.modules.advisory.pilots.rajshahi_aman import RAJSHAHI_AMAN_PILOT
from app.modules.advisory.service import AdvisoryService
from scripts.build_pilot_analysis import build_analysis, build_han_analysis

REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURE_DIR = REPO_ROOT / "demo_fixtures" / "nasa_power"
ANALYSIS_PATH = REPO_ROOT / "demo_fixtures" / "analysis" / "rajshahi_aman_analysis.json"


def _fail_transport(request: httpx.Request) -> httpx.Response:
    raise AssertionError(f"Network call attempted in offline mode: {request.url}")


def _real_fixture_present() -> bool:
    manifest_path = FIXTURE_DIR / "manifest.json"
    return manifest_path.exists() and any(FIXTURE_DIR.glob("*.json"))


requires_real_fixture = pytest.mark.skipif(
    not _real_fixture_present(),
    reason="Real NASA POWER demo fixture not committed in this checkout",
)


class TestPilotConfigHasSources:
    def test_every_numeric_assumption_has_a_source_reference(self) -> None:
        pilot = RAJSHAHI_AMAN_PILOT
        assert len(pilot.source_references) >= 3
        for ref in pilot.source_references:
            assert ref.title
            assert ref.organization
            assert ref.url.startswith("http")
            assert ref.accessed
            assert ref.claim

    def test_location_source_documents_what_the_coordinate_represents(self) -> None:
        assert "administrative" in RAJSHAHI_AMAN_PILOT.coordinate_meaning.lower()
        assert "farm" not in RAJSHAHI_AMAN_PILOT.coordinate_meaning.lower().split(",")[0]

    def test_gdd_base_temperature_honesty_flag_is_false(self) -> None:
        """The source document could not directly quote the primary
        ORYZA2000 citation, so this must stay False - a True here would
        silently let a future recommendation treat GDD as verified."""
        assert RAJSHAHI_AMAN_PILOT.gdd_base_temperature_verified is False


class TestCanonicalFixtureNaming:
    @requires_real_fixture
    def test_canonical_fixture_filename_matches_cache_key(self) -> None:
        pilot = RAJSHAHI_AMAN_PILOT
        from datetime import date

        key = canonical_cache_key(
            latitude=pilot.latitude,
            longitude=pilot.longitude,
            start=date(pilot.reference_start_year, 1, 1),
            end=date(pilot.recent_end_year, 12, 31),
            parameters=DEFAULT_PARAMETERS,
            community="AG",
        )
        assert (FIXTURE_DIR / f"{key}.json").exists()

    @requires_real_fixture
    def test_manifest_declares_not_synthetic(self) -> None:
        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        assert manifest["synthetic"] is False
        for entry in manifest["files"]:
            assert entry["synthetic"] is False


class TestRealFixtureIntegrityAndOfflineReplay:
    @requires_real_fixture
    def test_real_fixture_manifest_checksum_validates(self) -> None:
        from app.integrations.nasa.power_cache import verify_fixture_entry

        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        for entry in manifest["files"]:
            verify_fixture_entry(FIXTURE_DIR, entry["file"])  # raises on any problem

    @requires_real_fixture
    def test_tampered_copy_of_the_real_fixture_is_rejected(self, tmp_path: Path) -> None:
        from app.integrations.nasa.power_cache import verify_fixture_entry

        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        entry = manifest["files"][0]
        fixture_name = entry["file"]

        (tmp_path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        original_bytes = (FIXTURE_DIR / fixture_name).read_bytes()
        tampered = bytearray(original_bytes)
        tampered[0:1] = b"X" if tampered[0:1] != b"X" else b"Y"
        (tmp_path / fixture_name).write_bytes(bytes(tampered))

        with pytest.raises(NasaEvidenceIntegrityError, match="(?i)checksum"):
            verify_fixture_entry(tmp_path, fixture_name)

    @requires_real_fixture
    def test_offline_replay_makes_zero_nasa_http_calls(self) -> None:
        pilot = RAJSHAHI_AMAN_PILOT
        from datetime import date

        async def run() -> tuple[str, str, str]:
            client = NasaPowerClient(base_url="https://power.larc.nasa.gov", timeout_seconds=5.0)
            object.__setattr__(
                client, "_client", httpx.AsyncClient(transport=httpx.MockTransport(_fail_transport))
            )
            cache = NasaPowerCache(
                client=client,
                cache_dir=FIXTURE_DIR.parent / ".pytest_offline_scratch",
                fixture_dir=FIXTURE_DIR,
                offline=True,
            )
            lookup = await cache.get_daily_point(
                latitude=pilot.latitude,
                longitude=pilot.longitude,
                start=date(pilot.reference_start_year, 1, 1),
                end=date(pilot.recent_end_year, 12, 31),
                parameters=DEFAULT_PARAMETERS,
                community="AG",
            )
            await client.aclose()
            return (
                lookup.source,
                lookup.response.provenance.source_url,
                lookup.response.provenance.retrieved_at.isoformat(),
            )

        source, source_url, retrieved_at = asyncio.run(run())

        assert source == "fixture"
        # Original NASA request survives - never a file:// or "now" stand-in.
        assert source_url.startswith("https://power.larc.nasa.gov")
        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        entry = manifest["files"][0]
        assert source_url == entry["source_url"]
        assert retrieved_at == entry["retrieved_at"]


class TestAnalysisArtifact:
    @requires_real_fixture
    def test_analysis_output_references_exact_fixture_sha(self) -> None:
        result = asyncio.run(build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        assert result["source_fixture_sha256"] == manifest["files"][0]["sha256"]

    @requires_real_fixture
    def test_analysis_output_is_deterministic(self) -> None:
        first = asyncio.run(build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        second = asyncio.run(build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        first.pop("generated_at")
        second.pop("generated_at")
        assert first == second

    @requires_real_fixture
    def test_sensitivity_contains_15_20_25_mm(self) -> None:
        result = asyncio.run(build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        thresholds = {point["threshold_mm"] for point in result["sensitivity"]}
        assert thresholds == {15.0, 20.0, 25.0}

    @requires_real_fixture
    def test_missing_precipitation_values_are_never_coerced_to_zero(self) -> None:
        """This asserts the *reporting* invariant end to end: the count of
        missing days is carried through explicitly rather than folded
        into a total that would hide a None-as-zero substitution. See
        `app/compute/agro.py` for where the None-vs-0.0 distinction is
        enforced at the source."""
        result = asyncio.run(build_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        missing = result["missing_data"]
        assert "days_missing_precipitation" in missing
        assert isinstance(missing["days_missing_precipitation"], int)
        assert missing["days_missing_precipitation"] >= 0

    def test_no_ml_or_llm_dependency_in_analysis_script(self) -> None:
        script_path = (
            Path(__file__).resolve().parents[1] / "scripts" / "build_pilot_analysis.py"
        )
        tree = ast.parse(script_path.read_text(encoding="utf-8"))

        forbidden_substrings = (
            "openai",
            "anthropic",
            "langchain",
            "gpt",
            "llm",
            "sklearn",
            "xgboost",
            "torch",
            "tensorflow",
            "keras",
        )
        imported_modules: list[str] = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported_modules.extend(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported_modules.append(node.module)

        for module_name in imported_modules:
            lowered = module_name.lower()
            assert not any(forbidden in lowered for forbidden in forbidden_substrings), (
                f"build_pilot_analysis.py imports '{module_name}', which looks like an "
                "ML/LLM dependency - this phase's analysis path must stay pure statistics"
            )


class TestHanMethodAnalysisArtifact:
    """Task 19 (Phase 4A.2b) coverage items 1-2, 8, 10 - the Han method
    itself, run against the real fixture."""

    @requires_real_fixture
    def test_han_method_executes_end_to_end_against_real_fixture(self) -> None:
        result = asyncio.run(build_han_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        assert result["data_status"] == "ok"
        assert result["method_id"] == "han_agronomic_onset_v1"
        assert result["method_source_doi"] == "10.1007/s10584-024-03736-z"

    @requires_real_fixture
    def test_han_analysis_references_unchanged_fixture_sha(self) -> None:
        manifest = json.loads((FIXTURE_DIR / "manifest.json").read_text(encoding="utf-8"))
        result = asyncio.run(build_han_analysis(RAJSHAHI_AMAN_PILOT, fixture_dir=FIXTURE_DIR))
        assert result["source_fixture_sha256"] == manifest["files"][0]["sha256"]

    def test_no_ml_or_llm_dependency_in_monsoon_onset_module(self) -> None:
        module_path = (
            Path(__file__).resolve().parents[1] / "app" / "compute" / "monsoon_onset.py"
        )
        tree = ast.parse(module_path.read_text(encoding="utf-8"))

        forbidden_substrings = (
            "openai",
            "anthropic",
            "langchain",
            "gpt",
            "llm",
            "sklearn",
            "xgboost",
            "torch",
            "tensorflow",
            "keras",
            "fastapi",
            "httpx",
            "sqlalchemy",
        )
        imported_modules: list[str] = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported_modules.extend(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported_modules.append(node.module)

        for module_name in imported_modules:
            lowered = module_name.lower()
            assert not any(forbidden in lowered for forbidden in forbidden_substrings), (
                f"monsoon_onset.py imports '{module_name}' - this module must stay a "
                "pure computation with no FastAPI/HTTP/DB/LLM dependency"
            )


class TestProductionPilotSafetyGate:
    """Task 19 (Phase 4A.2b) coverage items 3-7, 9 - proves the live
    `AdvisoryService.compute_pilot_planting_window` path, against the real
    fixture, honors `pilot.decision_enabled` rather than the raw
    comparison/sensitivity result alone."""

    @requires_real_fixture
    def test_production_recommendation_is_blocked_while_decision_disabled(self) -> None:
        assert RAJSHAHI_AMAN_PILOT.decision_enabled is False

        async def run() -> object:
            client = NasaPowerClient(base_url="https://power.larc.nasa.gov", timeout_seconds=5.0)
            cache = NasaPowerCache(
                client=client,
                cache_dir=FIXTURE_DIR.parent / ".pytest_service_scratch",
                fixture_dir=FIXTURE_DIR,
                offline=True,
            )
            service = AdvisoryService(cache=cache)
            response = await service.compute_pilot_planting_window(RAJSHAHI_AMAN_PILOT)
            await client.aclose()
            return response

        response = asyncio.run(run())

        assert response.recommendation_status == "methodology_unvalidated"
        assert response.recommended_window is None
        assert response.applied_shift_days is None
        # The raw computed climate shift is still visible - it is simply
        # never turned into a farmer-facing date while the gate is closed.
        assert response.computed_climate_shift_days is not None
        assert response.han_method.computed_climate_shift_days is not None
        assert response.han_method.method_id == "han_agronomic_onset_v1"
        assert response.han_method.method_source_doi == "10.1007/s10584-024-03736-z"
        assert response.han_method.decision_enabled is False
        # NASA provenance must remain present even while gated.
        assert response.provenance.source_url.startswith("https://power.larc.nasa.gov")
        assert response.evidence_integrity.fixture_sha256 is not None
        # No GDD-based claim is introduced by this gate.
        assert "gdd" not in response.headline_bn.lower()
        assert "gdd" not in response.headline_en.lower()
        assert "X দিন আগে" not in response.headline_bn
        assert "X দিন পরে" not in response.headline_bn

    @requires_real_fixture
    def test_effective_decision_enabled_matches_freshly_computed_validation_status(self) -> None:
        """Phase 4A.2c: `han_method.decision_enabled` must never be True
        unless this same response's own freshly computed
        `validation_status` is 'validated' - it must not simply mirror the
        static `pilot.decision_enabled` flag. Since this repository has no
        independent evidence source, `validation_status` is
        'insufficient_evidence' here, so `decision_enabled` must be False
        regardless of what the static pilot flag says."""

        async def run() -> object:
            client = NasaPowerClient(base_url="https://power.larc.nasa.gov", timeout_seconds=5.0)
            cache = NasaPowerCache(
                client=client,
                cache_dir=FIXTURE_DIR.parent / ".pytest_validation_scratch",
                fixture_dir=FIXTURE_DIR,
                offline=True,
            )
            service = AdvisoryService(cache=cache)
            response = await service.compute_pilot_planting_window(RAJSHAHI_AMAN_PILOT)
            await client.aclose()
            return response

        response = asyncio.run(run())

        assert response.han_method.validation_status in (
            "validated",
            "transfer_uncertain",
            "invalidated",
            "insufficient_evidence",
        )
        assert isinstance(response.han_method.validation_reason_codes, list)
        assert len(response.han_method.validation_reason_codes) >= 1
        if response.han_method.validation_status != "validated":
            assert response.han_method.decision_enabled is False
        # Against the real committed fixture and no independent evidence
        # source in this repository, this must currently be exactly this.
        assert response.han_method.validation_status == "insufficient_evidence"
        assert response.han_method.decision_enabled is False

    @requires_real_fixture
    def test_gated_headline_never_leaks_recommendation_wording_regardless_of_validation_status(
        self,
    ) -> None:
        """Regression guard (Phase 4A.2c Task 20): while gated, the
        headline/SMS text must never contain instructive planting-date
        wording, no matter what `validation_status` computed to."""

        async def run() -> object:
            client = NasaPowerClient(base_url="https://power.larc.nasa.gov", timeout_seconds=5.0)
            cache = NasaPowerCache(
                client=client,
                cache_dir=FIXTURE_DIR.parent / ".pytest_leak_scratch",
                fixture_dir=FIXTURE_DIR,
                offline=True,
            )
            service = AdvisoryService(cache=cache)
            response = await service.compute_pilot_planting_window(RAJSHAHI_AMAN_PILOT)
            await client.aclose()
            return response

        response = asyncio.run(run())
        assert response.recommendation_status == "methodology_unvalidated"
        assert response.recommended_window is None
        assert response.applied_shift_days is None
        forbidden_bn_fragments = ("রোপণ উইন্ডো:", "প্রস্তাবিত রোপণ:")
        for fragment in forbidden_bn_fragments:
            assert fragment not in response.headline_bn
            assert fragment not in response.sms_bn
        assert "suggested transplanting window" not in response.headline_en.lower()
