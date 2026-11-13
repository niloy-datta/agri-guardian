"""First-party farmer inputs for rotation scenarios (dataset #4).

Validated, in-memory value object. Field geometry is owned by
`app.modules.fields`; this object carries only the scenario inputs the
farmer chooses to share, and is never pooled across farmers.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from enum import StrEnum

from app.integrations.common.geo import validate_lat_lon


class Irrigation(StrEnum):
    NONE = "none"
    SUPPLEMENTARY = "supplementary"
    FULL = "full"


class Outcome(StrEnum):
    INCOME = "income"
    FOOD_SECURITY = "food_security"
    SOIL_HEALTH = "soil_health"
    WATER_SAVING = "water_saving"
    LOW_RISK = "low_risk"


@dataclass(frozen=True, slots=True)
class FarmerRotationProfile:
    latitude: float
    longitude: float
    previous_crops: tuple[str, ...]
    """Most recent first."""
    irrigation: Irrigation
    budget_bdt: Decimal | None = None
    preferred_outcomes: tuple[Outcome, ...] = ()
    field_id: str | None = None
    consent_to_personalise: bool = False
    notes: dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        validate_lat_lon(self.latitude, self.longitude, provider="farmer_profile")
        if self.budget_bdt is not None and self.budget_bdt < 0:
            raise ValueError("budget_bdt must be non-negative")
        if len(set(self.preferred_outcomes)) != len(self.preferred_outcomes):
            raise ValueError("preferred_outcomes must not repeat")

    @property
    def is_irrigated(self) -> bool:
        return self.irrigation is not Irrigation.NONE

    def explanation_context(self) -> dict[str, object]:
        """What a scenario explanation may cite - only if the farmer consented."""
        if not self.consent_to_personalise:
            return {}
        return {
            "previous_crops": list(self.previous_crops),
            "irrigation": self.irrigation.value,
            "budget_bdt": str(self.budget_bdt) if self.budget_bdt is not None else None,
            "preferred_outcomes": [o.value for o in self.preferred_outcomes],
        }
