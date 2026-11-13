"""Farmer profile (schema: `farm`).

The farm-domain identity of a user. Fields, crop cycles and harvests hang
off this rather than off `identity.users` directly, so the farm domain can
be extracted later without dragging the whole identity schema with it.
"""

import uuid

from sqlalchemy import ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class FarmerProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "farmer_profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_farm_farmer_profiles_user_id"),
        Index("ix_farm_farmer_profiles_country", "country_code"),
        {"schema": "farm"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="CASCADE"),
        nullable=False,
    )
    display_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    # ISO 3166-1 alpha-2. Drives the country pack (crop codes, units, currency).
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    region: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
    upazila: Mapped[str | None] = mapped_column(String(120), nullable=True)
    farming_since_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    primary_language: Mapped[str] = mapped_column(String(10), nullable=False, default="en")
