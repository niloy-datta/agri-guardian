"""Buyer profile response contract."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class BuyerProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    display_name: str | None = None
    business_name: str | None = None
    country_code: str | None = None
    region: str | None = None
    district: str | None = None
    created_at: datetime
    updated_at: datetime
    version: int
