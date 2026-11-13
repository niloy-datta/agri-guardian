"""Listing request/response contracts.

Money and quantity are never floats on the wire: `asking_price_minor` is an
integer count of minor currency units, `quantity_*` are `Decimal` strings
(matching `FieldRead.area_sq_m`'s existing convention for the same reason).
"""

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.shared.enums import DeliveryMode, ListingKind, QuantityUnit


class CropAttributes(BaseModel):
    """Optional CROP-specific details. Money/inventory never live here."""

    model_config = ConfigDict(extra="forbid")

    variety: str | None = Field(default=None, max_length=120)
    quality_notes: str | None = Field(default=None, max_length=500)
    moisture_percent: float | None = Field(default=None, ge=0, le=100)
    packaging: str | None = Field(default=None, max_length=120)


class FishAttributes(BaseModel):
    """Optional FISH-specific details. Money/inventory never live here."""

    model_config = ConfigDict(extra="forbid")

    species: str | None = Field(default=None, max_length=120)
    average_weight_grams: float | None = Field(default=None, gt=0)
    estimated_biomass_kg: float | None = Field(default=None, gt=0)
    harvest_method: str | None = Field(default=None, max_length=120)
    pond_reference: str | None = Field(default=None, max_length=120)


class ListingCreate(BaseModel):
    listing_kind: ListingKind
    product_code: str | None = Field(default=None, max_length=64)
    product_name: str = Field(min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=4000)

    field_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None

    quantity_total: Decimal = Field(gt=0)
    quantity_unit: QuantityUnit

    asking_price_minor: int | None = Field(default=None, ge=0)
    currency: str = Field(min_length=3, max_length=3)

    grade: str | None = Field(default=None, max_length=80)
    harvest_date: date | None = None
    available_from: date | None = None
    delivery_mode: DeliveryMode

    country_code: str = Field(min_length=2, max_length=2)
    region: str | None = Field(default=None, max_length=120)
    district: str | None = Field(default=None, max_length=120)
    upazila: str | None = Field(default=None, max_length=120)

    attributes: dict[str, Any] = Field(default_factory=dict)

    @field_validator("currency")
    @classmethod
    def _upper_currency(cls, value: str) -> str:
        if not value.isalpha():
            raise ValueError("currency must be a 3-letter ISO-4217 code")
        return value.upper()

    @field_validator("country_code")
    @classmethod
    def _upper_country(cls, value: str) -> str:
        if not value.isalpha():
            raise ValueError("country_code must be an ISO 3166-1 alpha-2 code")
        return value.upper()

    @model_validator(mode="after")
    def _validate_attributes_for_kind(self) -> "ListingCreate":
        """Product-specific `attributes` are optional, but if present they
        must match the shape for this listing's kind - never silently
        accepted as an opaque bag that could hide a money/quantity field."""
        if not self.attributes:
            return self
        schema = CropAttributes if self.listing_kind == ListingKind.CROP else FishAttributes
        validated = schema.model_validate(self.attributes)
        self.attributes = validated.model_dump(exclude_none=True)
        return self


class ListingUpdate(BaseModel):
    """Reserved for a future phase - no fields yet. Listing mutation in
    this phase is limited to the explicit `close` action."""


class SellerSummaryOut(BaseModel):
    """Safe, minimal seller display info - never email/phone."""

    farmer_id: uuid.UUID
    display_name: str | None = None


class ListingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    seller_farmer_id: uuid.UUID
    seller: SellerSummaryOut
    field_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None

    listing_kind: str
    product_code: str | None = None
    product_name: str
    description: str | None = None

    quantity_total: Decimal
    quantity_available: Decimal
    quantity_unit: str

    asking_price_minor: int | None = None
    currency: str

    grade: str | None = None
    harvest_date: date | None = None
    available_from: date | None = None
    is_future_harvest: bool = False
    delivery_mode: str

    country_code: str
    region: str | None = None
    district: str | None = None
    upazila: str | None = None

    attributes: dict[str, Any]
    status: str

    created_at: datetime
    updated_at: datetime
    version: int


class ListingCloseResult(BaseModel):
    id: uuid.UUID
    status: str
    version: int
