"""Typed request/response models for location, dataset and rotation APIs."""

from __future__ import annotations

from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

from app.modules.rotation.models import OUTCOMES

Irrigation = Literal["none", "supplementary", "full"]
Outcome = Literal["income", "food_security", "soil_health", "water_saving", "low_risk"]


class PointIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class PolygonIn(BaseModel):
    ring: list[tuple[float, float]] = Field(min_length=4, description="[lon, lat] vertices, closed")


class LocationOut(BaseModel):
    latitude: float
    longitude: float
    in_bangladesh: bool
    district: str | None
    division: str | None
    near_boundary: bool
    bamis_region: str | None
    calendar_crops: list[str]


class DistrictOut(BaseModel):
    name: str
    division: str
    geonames_id: int
    latitude: float
    longitude: float
    bamis_region: str | None


class CalendarWindowOut(BaseModel):
    crop: str
    region: str | None
    start: str
    end: str
    duration_days: str | None
    verified: bool
    qa_note: str
    source_url: str


class DatasetOut(BaseModel):
    number: int
    key: str
    name: str
    access: str
    use: str
    caveat: str
    resolution: str | None
    product: str | None
    doi: str | None
    id_confirmed: bool
    status: str
    blocker: str
    last_updated: str | None = None
    acquired: str = "UNKNOWN"
    validated: str = "UNKNOWN"
    integrated: str = "UNKNOWN"
    tested: str = "UNKNOWN"


class RotationProfileIn(BaseModel):
    previous_crops: list[str] = Field(default_factory=list, max_length=12)
    irrigation_access: Irrigation
    budget_bdt: Decimal | None = Field(default=None, ge=0)
    preferred_outcomes: list[Outcome] = Field(default_factory=list, max_length=5)
    consent_to_personalise: bool = False

    @field_validator("preferred_outcomes")
    @classmethod
    def _unique(cls, v: list[str]) -> list[str]:
        if len(set(v)) != len(v) or not set(v) <= set(OUTCOMES):
            raise ValueError("preferred_outcomes must be unique known outcomes")
        return v


class RotationProfileOut(RotationProfileIn):
    field_id: str
    version: int


class ScenarioRequest(BaseModel):
    max_overlap_days: int = Field(default=0, ge=0, le=45)
    preferred_outcomes: list[Outcome] | None = None
    irrigation_access: Irrigation | None = None


class AdHocScenarioRequest(PointIn, ScenarioRequest):
    pass


class ClaimOut(BaseModel):
    text: str
    source: str
    uncertainty: str


class ScenarioOut(BaseModel):
    crops: list[str]
    overlap_days: int
    irrigation_dependent: list[str]
    unknown_water_need: list[str]
    rice_seasons: int
    has_pulse: bool
    weakest_gaez_index: int | None
    claims: list[ClaimOut]


class EvidenceOut(BaseModel):
    dataset: int
    name: str
    status: str
    resolution: str
    source_url: str
    caveat: str
    values: dict[str, Any]
    reason: str


class RotationOut(BaseModel):
    status: Literal["OK", "INSUFFICIENT_EVIDENCE"]
    location: LocationOut
    scenarios: list[ScenarioOut]
    excluded: list[dict[str, str]]
    unsupported_priorities: list[str]
    reasons: list[str]
    evidence: list[EvidenceOut]
    retrieved_at: str
    disclaimer: str = (
        "Scenarios compare calendar fit and modelled suitability only. No yield, income or "
        "confidence figure is estimated. Confirm with your Upazila Agriculture Officer."
    )
