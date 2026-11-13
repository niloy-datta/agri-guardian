"""The single verified Rajshahi Aman pilot configuration.

Every value here is sourced in `docs/references/rajshahi_aman_pilot.md`.
This module is intentionally NOT a generic config engine - see that
document for exactly what was and was not independently verified, and
`app/compute/planting_policy.py` for how `gdd_base_temperature_verified`
is honored (a false value means GDD never drives or labels a
recommendation, per that source document's own honesty finding).
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class SourceReference:
    title: str
    organization: str
    url: str
    accessed: str
    claim: str


@dataclass(frozen=True, slots=True)
class RajshahiAmanPilot:
    pilot_id: str = "rajshahi_aman"

    location_name_en: str = "Rajshahi"
    location_name_bn: str = "রাজশাহী"

    # GeoNames ID 1185128 - Rajshahi city, seat of Rajshahi Division.
    # A city-center administrative point, NOT a farm or field.
    latitude: float = 24.37400
    longitude: float = 88.60114
    coordinate_meaning: str = (
        "GeoNames PPPLA (seat of a first-order administrative division): "
        "Rajshahi city, the administrative seat of Rajshahi Division. "
        "This is a city-center point, not a farm, field, or research station."
    )

    crop_code: str = "AMAN_RICE"
    crop_name_en: str = "Aman rice (transplanted, monsoon-season)"
    crop_name_bn: str = "আমন ধান"

    # BRRI-hosted "Rice Crop Calendar of Bangladesh" (source: BBS Year Book
    # of Agricultural Statistics-2023), Aman Paddy / HYV Transplant row.
    # National figure, NOT Rajshahi-specific - see the source document.
    baseline_window_type: str = "transplanting"
    baseline_window_start_month_day: tuple[int, int] = (6, 25)
    """Late June, approximated as June 25 for date arithmetic. See source
    document for the exact quoted text ("Late June to Mid-August")."""
    baseline_window_end_month_day: tuple[int, int] = (8, 15)
    """Mid-August, approximated as August 15."""

    # NOT independently primary-source-verified in this project (see
    # docs/references/rajshahi_aman_pilot.md). Carried only as disclosed,
    # non-authoritative supporting context - never used to drive or word
    # the window-shift recommendation, and never presented as a "GDD
    # shift" claim.
    gdd_base_temperature_c: float = 8.0
    gdd_base_temperature_verified: bool = False
    gdd_base_temperature_citation: str = (
        "Cited to Bouman et al. (2001), ORYZA2000: Modeling Lowland Rice "
        "(IRRI/Wageningen); NOT independently confirmed against the "
        "primary document in this project - see docs/references/"
        "rajshahi_aman_pilot.md."
    )

    reference_start_year: int = 2001
    reference_end_year: int = 2012
    recent_start_year: int = 2013
    recent_end_year: int = 2025

    # This project's own analytical definition (matching the NASA Space
    # Apps "Field Shift" challenge guide's structure) - not attributed to
    # any agronomy source. See docs/references/rajshahi_aman_pilot.md.
    # Kept exactly as-is (never silently changed) so this method - now
    # named `usable_rain_v1` at the call site - stays reproducible
    # alongside the newer `han_agronomic_onset_v1` method below. See
    # docs/references/han_2024_nasa_power_transfer_review.md explains the second method.
    rain_window_days: int = 7
    rain_threshold_mm: float = 20.0
    dry_spell_max_days: int = 7

    # ============================================================
    # Han et al. (2024) agronomic monsoon-onset method ("Dynamic 2")
    # ============================================================
    # Every value below is the paper's Rajshahi row of Table 1 - see
    # docs/references/han_2024_agronomic_onset.md for the verified
    # citation and exact quoted algorithm. `app/compute/monsoon_onset.py`
    # implements the pure computation; nothing here hard-codes any part
    # of that algorithm.
    onset_method_id: str = "han_agronomic_onset_v1"

    han_lws_days: int = 3
    """Length of initial Wet Spell (days) - Han et al. (2024) Table 1, Rajshahi."""
    han_aws_mm: float = 31.0
    """Cumulative rainfall (mm) required during the wet spell - Rajshahi."""
    han_lds_days: int = 6
    """Length of post-onset Dry Spell (days) - Rajshahi. The paper itself
    cautions this value may be too strict for Rajshahi's relatively dry
    climate - see docs/references/han_2024_agronomic_onset.md and
    docs/references/han_2024_nasa_power_transfer_review.md."""
    han_ads_mm: float = 11.0
    """Rainfall ceiling (mm) for the post-onset dry spell to disqualify
    the candidate onset - Rajshahi."""

    han_search_start_month_day: tuple[int, int] = (5, 15)
    han_search_end_month_day: tuple[int, int] = (10, 31)
    han_wet_day_threshold_mm: float = 1.0
    han_dry_day_threshold_mm: float = 1.0
    han_post_onset_lookahead_days: int = 20

    method_source_doi: str = "10.1007/s10584-024-03736-z"

    # ============================================================
    # Recommendation safety gate (Phase 4A.2b, Task 9)
    # ============================================================
    # All three MUST remain False until a documented review
    # (docs/references/han_2024_nasa_power_transfer_review.md) explicitly
    # justifies flipping them - see app/compute/planting_policy.py and
    # app/modules/advisory/service.py for how these gate the response.
    # Scientific abstention (leaving these False) is an acceptable,
    # intended outcome of this phase - not a bug to "fix" by flipping them.
    decision_enabled: bool = False
    methodology_validated_for_mukti: bool = False
    agronomic_link_validated: bool = False

    source_references: tuple[SourceReference, ...] = field(
        default_factory=lambda: (
            SourceReference(
                title="Rajshahi (GeoNames ID 1185128)",
                organization="GeoNames",
                url="https://www.geonames.org/1185128/rajshahi.html",
                accessed="2026-09-24",
                claim="Latitude 24.37400, longitude 88.60114; feature class "
                "PPPLA (seat of a first-order administrative division).",
            ),
            SourceReference(
                title="Rice Crop Calendar of Bangladesh",
                organization="Bangladesh Rice Research Institute (BRRI) portal; "
                "table sourced to BBS Year Book of Agricultural Statistics-2023",
                url=(
                    "https://objectstorage.ap-dcc-gazipur-1.oraclecloud15.com/"
                    "n/axvjbnqprylg/b/V2Ministry/o/office-brri/2024/12/"
                    "e703d402c1b24524b570a57bc6806044.pdf"
                ),
                accessed="2026-09-24",
                claim="Aman Paddy, HYV Transplant: transplanting 'Late June to "
                "Mid-August', harvest 'December to Early January'. National "
                "figure, not Rajshahi-specific.",
            ),
            SourceReference(
                title="ORYZA2000: Modeling Lowland Rice (cited, primary source unverified)",
                organization="Bouman, Kropff, Tuong, Wopereis, ten Berge, "
                "van Laar (2001) - IRRI/Wageningen",
                url="https://books.irri.org/9712201716_content.pdf",
                accessed="2026-09-24",
                claim="Reported (via secondary academic sources, not directly "
                "quoted from the primary document) to use 8/30/42 C cardinal "
                "temperatures for rice development rate.",
            ),
            SourceReference(
                title="NASA POWER Daily Point API",
                organization="NASA Langley Research Center",
                url="https://power.larc.nasa.gov/api/temporal/daily/point",
                accessed="2026-09-24",
                claim="Source of all historical rainfall/temperature evidence "
                "used by this pilot. Live-verified in Phase 4A.1.",
            ),
            SourceReference(
                title="Agronomic monsoon onset definitions to support "
                "planting decisions for rainfed rice in Bangladesh",
                organization="Han, Montes, Hussain, Krupnik (2024), "
                "Climatic Change 177(5), 77",
                url="https://doi.org/10.1007/s10584-024-03736-z",
                accessed="2026-09-27",
                claim="Rajshahi-fitted Dynamic-2 agronomic monsoon-onset "
                "parameters (LWS=3, AWS=31mm, LDS=6, ADS=11mm, search "
                "window May 15-Oct 31). Fitted against BMD gauge data "
                "1981-2017, not NASA POWER - applied here to NASA POWER "
                "data as a disclosed analytical choice, not a re-fit. "
                "Paper itself cautions LDS=6 may be too strict for "
                "Rajshahi's relatively dry climate.",
            ),
        )
    )


RAJSHAHI_AMAN_PILOT = RajshahiAmanPilot()
