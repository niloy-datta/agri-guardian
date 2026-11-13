"""Bid request/response contracts."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class BidCreate(BaseModel):
    quantity: Decimal = Field(gt=0)
    unit_price_minor: int = Field(gt=0)
    currency: str = Field(min_length=3, max_length=3)
    note: str | None = Field(default=None, max_length=2000)
    expires_at: datetime | None = None

    @field_validator("currency")
    @classmethod
    def _upper_currency(cls, value: str) -> str:
        if not value.isalpha():
            raise ValueError("currency must be a 3-letter ISO-4217 code")
        return value.upper()


class BuyerSummaryOut(BaseModel):
    """Safe, minimal buyer display info for the seller's bid inbox - never
    email/phone/raw identity data."""

    buyer_id: uuid.UUID
    display_name: str | None = None


class BidListingSummaryOut(BaseModel):
    """What product/listing this bid belongs to - joined in one query
    (Task 5) so `GET /my-bids` never needs one listing request per bid."""

    listing_id: uuid.UUID
    product_name: str
    listing_kind: str
    quantity_unit: str
    district: str | None = None
    status: str


class BidRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    listing_id: uuid.UUID
    buyer_id: uuid.UUID
    buyer: BuyerSummaryOut
    listing: BidListingSummaryOut
    quantity: Decimal
    unit_price_minor: int
    currency: str
    note: str | None = None
    status: str
    expires_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    version: int


class BidAcceptResult(BaseModel):
    bid: BidRead
    order_id: uuid.UUID
