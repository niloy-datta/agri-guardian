"""Order ORM models (schema: `commerce`).

`orders` is created exactly once, inside the same locked transaction that
accepts a bid (`app/modules/bidding/service.py`) - never independently.
`order_events` is a strictly append-only audit trail of what happened to
one order; existing rows are never updated.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import OrderStatus, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class Order(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_commerce_orders_quantity_positive"),
        CheckConstraint("unit_price_minor > 0", name="ck_commerce_orders_unit_price_positive"),
        CheckConstraint(
            "total_amount_minor >= 0", name="ck_commerce_orders_total_amount_non_negative"
        ),
        CheckConstraint(
            "status IN ('" + "','".join(values(OrderStatus)) + "')", name="ck_commerce_orders_status"
        ),
        Index("ix_commerce_orders_seller_created", "seller_farmer_id", "created_at", "id"),
        Index("ix_commerce_orders_buyer_created", "buyer_id", "created_at", "id"),
        {"schema": "commerce"},
    )

    listing_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.listings.id", ondelete="RESTRICT"),
        nullable=False,
    )
    accepted_bid_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.bids.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
    )
    seller_farmer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.farmer_profiles.id", ondelete="RESTRICT"),
        nullable=False,
    )
    buyer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.buyer_profiles.id", ondelete="RESTRICT"),
        nullable=False,
    )

    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False)
    quantity_unit: Mapped[str] = mapped_column(String(8), nullable=False)
    unit_price_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    total_amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)

    status: Mapped[str] = mapped_column(String(16), nullable=False, default=OrderStatus.CONFIRMED.value)


class OrderEvent(Base, UUIDPrimaryKeyMixin):
    """Append-only: rows here are never updated, only inserted."""

    __tablename__ = "order_events"
    __table_args__ = ({"schema": "commerce"},)

    order_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.orders.id", ondelete="CASCADE"),
        nullable=False,
    )
    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)
    # A plain TimestampMixin would also add `updated_at`, which an
    # append-only log has no use for - declared directly instead.
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
