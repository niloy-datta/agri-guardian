"""Buyer profile ORM model (schema: `commerce`).

A buyer profile is deliberately thin - an individual buyer with no
business/company name must work, so `display_name`/`business_name` are
both optional. It exists mainly to give bids and orders a stable
`buyer_id` that is not the raw `identity.users.id`, matching the same
separation `farm.farmer_profiles` already draws for sellers.
"""

import uuid

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class BuyerProfile(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "buyer_profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_commerce_buyer_profiles_user_id"),
        Index("ix_commerce_buyer_profiles_country", "country_code"),
        {"schema": "commerce"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="CASCADE"),
        nullable=False,
    )
    display_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    business_name: Mapped[str | None] = mapped_column(String(200), nullable=True)

    country_code: Mapped[str | None] = mapped_column(String(2), nullable=True)
    region: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
