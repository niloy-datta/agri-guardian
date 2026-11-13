"""Order request/response contracts."""

import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict


class OrderListingSummaryOut(BaseModel):
    """Compact listing context (Task 6) - no second request per order."""

    listing_id: uuid.UUID
    product_name: str
    listing_kind: str


class OrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    listing_id: uuid.UUID
    listing: OrderListingSummaryOut
    accepted_bid_id: uuid.UUID
    seller_farmer_id: uuid.UUID
    buyer_id: uuid.UUID
    seller_display_name: str | None = None
    buyer_display_name: str | None = None
    quantity: Decimal
    quantity_unit: str
    unit_price_minor: int
    total_amount_minor: int
    currency: str
    status: str
    created_at: datetime
    updated_at: datetime
    version: int
