"""Persistent farmer rotation profile (dataset #4, first-party, consent-aware).

One row per field. Owned by the field's farmer; read/write is authorised
through `FieldService.get_field` (404 for anyone else's field). Nothing
here is shared across farmers, exported, or sent to a provider.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin

IRRIGATION_ACCESS = ("none", "supplementary", "full")
OUTCOMES = ("income", "food_security", "soil_health", "water_saving", "low_risk")


class RotationProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "rotation_profiles"
    __table_args__ = (
        UniqueConstraint("field_id", name="uq_farm_rotation_profiles_field_id"),
        Index("ix_farm_rotation_profiles_farmer_id", "farmer_id"),
        CheckConstraint(
            "irrigation_access IN ('" + "','".join(IRRIGATION_ACCESS) + "')",
            name="ck_farm_rotation_profiles_irrigation",
        ),
        CheckConstraint(
            "budget_bdt IS NULL OR budget_bdt >= 0", name="ck_farm_rotation_profiles_budget"
        ),
        CheckConstraint(
            "consent_to_personalise = false OR consent_recorded_at IS NOT NULL",
            name="ck_farm_rotation_profiles_consent_time",
        ),
        {"schema": "farm"},
    )

    field_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.fields.id", ondelete="CASCADE"),
        nullable=False,
    )
    farmer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.farmer_profiles.id", ondelete="CASCADE"),
        nullable=False,
    )
    previous_crops: Mapped[list[str]] = mapped_column(
        ARRAY(String(40)), nullable=False, server_default="{}"
    )
    irrigation_access: Mapped[str] = mapped_column(String(20), nullable=False)
    budget_bdt: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), nullable=True)
    preferred_outcomes: Mapped[list[str]] = mapped_column(
        ARRAY(String(30)), nullable=False, server_default="{}"
    )
    consent_to_personalise: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    consent_recorded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
