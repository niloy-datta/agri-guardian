"""Crop cycle ORM model (schema: `farm`).

A crop cycle is the unit every intelligence feature is scoped to: a
planting of one crop on one field over one season. Risk assessments,
advisories and harvests all hang off a cycle, not off the field, so a
field's history stays intact across seasons.
"""

import uuid
from datetime import date

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    String,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import CropCycleStatus, IrrigationType, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class CropCycle(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "crop_cycles"
    __table_args__ = (
        CheckConstraint(
            "status IN ('" + "','".join(values(CropCycleStatus)) + "')",
            name="ck_farm_crop_cycles_status",
        ),
        CheckConstraint(
            "irrigation_type IS NULL OR irrigation_type IN ('"
            + "','".join(values(IrrigationType))
            + "')",
            name="ck_farm_crop_cycles_irrigation_type",
        ),
        CheckConstraint(
            "expected_harvest_date IS NULL OR planting_date IS NULL "
            "OR expected_harvest_date >= planting_date",
            name="ck_farm_crop_cycles_harvest_after_planting",
        ),
        Index("ix_farm_crop_cycles_field_created", "field_id", "created_at", "id"),
        Index("ix_farm_crop_cycles_status", "status"),
        {"schema": "farm"},
    )

    field_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.fields.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Regional crop code (e.g. a country pack's code list), not a global enum,
    # so local varieties are representable without schema changes.
    crop_code: Mapped[str] = mapped_column(String(64), nullable=False)
    variety: Mapped[str | None] = mapped_column(String(120), nullable=True)

    planting_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    expected_harvest_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    actual_harvest_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    current_stage: Mapped[str | None] = mapped_column(String(64), nullable=True)
    irrigation_type: Mapped[str | None] = mapped_column(String(24), nullable=True)
    status: Mapped[str] = mapped_column(
        String(24), nullable=False, default=CropCycleStatus.PLANNED.value
    )
