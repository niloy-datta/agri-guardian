"""Bid ORM model (schema: `commerce`).

A bid never reserves inventory by itself - several buyers can bid on the
same listing concurrently. Inventory is only touched inside the locked
bid-acceptance transaction (`app/modules/bidding/service.py`).
"""

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import BidStatus, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class Bid(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "bids"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_commerce_bids_quantity_positive"),
        CheckConstraint("unit_price_minor > 0", name="ck_commerce_bids_unit_price_positive"),
        CheckConstraint(
            "status IN ('" + "','".join(values(BidStatus)) + "')", name="ck_commerce_bids_status"
        ),
        Index("ix_commerce_bids_listing_created", "listing_id", "created_at", "id"),
        Index("ix_commerce_bids_buyer_created", "buyer_id", "created_at", "id"),
        Index("ix_commerce_bids_listing_status", "listing_id", "status"),
        {"schema": "commerce"},
    )

    listing_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.listings.id", ondelete="CASCADE"),
        nullable=False,
    )
    buyer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.buyer_profiles.id", ondelete="CASCADE"),
        nullable=False,
    )

    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False)
    unit_price_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[str] = mapped_column(String(16), nullable=False, default=BidStatus.ACTIVE.value)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
