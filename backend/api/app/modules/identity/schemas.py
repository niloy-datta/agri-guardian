"""Pydantic request/response contracts for the identity module."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.shared.enums import MeasurementSystem


class ProfileRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    display_name: str | None = None
    avatar_storage_key: str | None = None
    language: str
    timezone: str
    measurement_system: str
    preferred_currency: str | None = None


class ProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=160)
    language: str | None = Field(default=None, max_length=10)
    timezone: str | None = Field(default=None, max_length=64)
    measurement_system: MeasurementSystem | None = None
    preferred_currency: str | None = Field(default=None, min_length=3, max_length=3)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None = None
    phone: str | None = None
    country_code: str | None = None
    status: str
    roles: list[str] = []
    profile: ProfileRead | None = None
    created_at: datetime
    updated_at: datetime
    version: int
