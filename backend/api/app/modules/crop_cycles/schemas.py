"""Crop cycle request/response contracts."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.shared.enums import CropCycleStatus, IrrigationType


class CropCycleCreate(BaseModel):
    crop_code: str = Field(min_length=1, max_length=64)
    variety: str | None = Field(default=None, max_length=120)
    planting_date: date | None = None
    expected_harvest_date: date | None = None
    irrigation_type: IrrigationType | None = None
    current_stage: str | None = Field(default=None, max_length=64)
    status: CropCycleStatus = CropCycleStatus.PLANNED

    @model_validator(mode="after")
    def _check_dates(self) -> "CropCycleCreate":
        if (
            self.planting_date is not None
            and self.expected_harvest_date is not None
            and self.expected_harvest_date < self.planting_date
        ):
            raise ValueError("expected_harvest_date cannot precede planting_date")
        return self


class CropCycleUpdate(BaseModel):
    variety: str | None = Field(default=None, max_length=120)
    planting_date: date | None = None
    expected_harvest_date: date | None = None
    actual_harvest_date: date | None = None
    current_stage: str | None = Field(default=None, max_length=64)
    irrigation_type: IrrigationType | None = None
    status: CropCycleStatus | None = None
    expected_version: int | None = Field(default=None, ge=1)


class CropCycleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    field_id: uuid.UUID
    crop_code: str
    variety: str | None = None
    planting_date: date | None = None
    expected_harvest_date: date | None = None
    actual_harvest_date: date | None = None
    current_stage: str | None = None
    irrigation_type: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime
    version: int
