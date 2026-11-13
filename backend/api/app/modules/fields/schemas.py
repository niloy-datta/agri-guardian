"""Field request/response contracts.

Polygon validation happens here (structural) and in PostGIS (topological),
so a malformed boundary is rejected with 422 before any write is attempted.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import BaseModel, ConfigDict, field_validator
from pydantic import Field as PydanticField

from app.shared.enums import FieldStatus
from app.shared.geo import InvalidGeometryError, validate_polygon_geojson


class Centroid(BaseModel):
    longitude: float
    latitude: float


class FieldCreate(BaseModel):
    name: str = PydanticField(min_length=1, max_length=160)
    boundary: dict[str, Any] = PydanticField(
        description="GeoJSON Polygon in EPSG:4326 (WGS84), outer ring first."
    )
    country_code: str = PydanticField(min_length=2, max_length=2)
    region: str | None = PydanticField(default=None, max_length=120)
    district: str | None = PydanticField(default=None, max_length=120)
    upazila: str | None = PydanticField(default=None, max_length=120)

    @field_validator("boundary")
    @classmethod
    def _validate_boundary(cls, value: dict[str, Any]) -> dict[str, Any]:
        try:
            return validate_polygon_geojson(value)
        except InvalidGeometryError as exc:
            raise ValueError(str(exc)) from exc

    @field_validator("country_code")
    @classmethod
    def _upper_country(cls, value: str) -> str:
        if not value.isalpha():
            raise ValueError("country_code must be an ISO 3166-1 alpha-2 code")
        return value.upper()


class FieldUpdate(BaseModel):
    name: str | None = PydanticField(default=None, min_length=1, max_length=160)
    region: str | None = PydanticField(default=None, max_length=120)
    district: str | None = PydanticField(default=None, max_length=120)
    upazila: str | None = PydanticField(default=None, max_length=120)
    status: FieldStatus | None = None
    # Optimistic concurrency: the version the client last saw.
    expected_version: int | None = PydanticField(default=None, ge=1)


class FieldRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    farmer_id: uuid.UUID
    name: str
    boundary: dict[str, Any]
    centroid: Centroid
    area_sq_m: Decimal
    area_acres: float
    country_code: str
    region: str | None = None
    district: str | None = None
    upazila: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime
    version: int
