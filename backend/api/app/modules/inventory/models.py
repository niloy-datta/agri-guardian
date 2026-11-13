"""Inventory reservation ORM model (schema: `commerce`).

A reservation is created exactly once, inside the same locked transaction
that accepts a bid and creates its order - never speculatively for an
unaccepted bid. `order_id` is unique, so a reservation is always exactly
one order's inventory claim.
"""

import uuid
from decimal import Decimal

from sqlalchemy import CheckConstraint, ForeignKey, Index, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import InventoryReservationStatus, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin


class InventoryReservation(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "inventory_reservations"
    __table_args__ = (
        CheckConstraint("quantity > 0", name="ck_commerce_inventory_reservations_quantity_positive"),
        CheckConstraint(
            "status IN ('" + "','".join(values(InventoryReservationStatus)) + "')",
            name="ck_commerce_inventory_reservations_status",
        ),
        # One reservation per accepted order - the order <-> reservation
        # relationship is always 1:1 in this phase.
        UniqueConstraint("order_id", name="uq_commerce_inventory_reservations_order_id"),
        Index("ix_commerce_inventory_reservations_listing_status", "listing_id", "status"),
        {"schema": "commerce"},
    )

    listing_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.listings.id", ondelete="CASCADE"),
        nullable=False,
    )
    bid_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.bids.id", ondelete="CASCADE"),
        nullable=False,
    )
    order_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("commerce.orders.id", ondelete="CASCADE"),
        nullable=False,
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=InventoryReservationStatus.ACTIVE.value
    )
