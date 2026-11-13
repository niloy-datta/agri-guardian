"""Listing ORM model (schema: `commerce`).

A listing is a farmer's offer of crop or fish produce, already harvested
or still on the way (`harvest_date`/`available_from`). `quantity_available`
is the single source of truth inventory relies on - it is only ever
decremented inside the locked bid-acceptance transaction
(`app/modules/bidding/service.py`), never by a bid being placed.
"""

import uuid
from datetime import date
from decimal import Decimal
from typing import Any

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import DeliveryMode, ListingKind, ListingStatus, QuantityUnit, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class Listing(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "listings"
    __table_args__ = (
        CheckConstraint("quantity_total > 0", name="ck_commerce_listings_quantity_total_positive"),
        CheckConstraint(
            "quantity_available >= 0", name="ck_commerce_listings_quantity_available_non_negative"
        ),
        CheckConstraint(
            "quantity_available <= quantity_total",
            name="ck_commerce_listings_quantity_available_le_total",
        ),
        CheckConstraint(
            "asking_price_minor IS NULL OR asking_price_minor >= 0",
            name="ck_commerce_listings_asking_price_non_negative",
        ),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_commerce_listings_currency_format"),
        CheckConstraint(
            "listing_kind IN ('" + "','".join(values(ListingKind)) + "')",
            name="ck_commerce_listings_kind",
        ),
        CheckConstraint(
            "status IN ('" + "','".join(values(ListingStatus)) + "')",
            name="ck_commerce_listings_status",
        ),
        CheckConstraint(
            "quantity_unit IN ('" + "','".join(values(QuantityUnit)) + "')",
            name="ck_commerce_listings_quantity_unit",
        ),
        CheckConstraint(
            "delivery_mode IN ('" + "','".join(values(DeliveryMode)) + "')",
            name="ck_commerce_listings_delivery_mode",
        ),
        Index("ix_commerce_listings_seller_created", "seller_farmer_id", "created_at", "id"),
        Index("ix_commerce_listings_status_created", "status", "created_at", "id"),
        Index("ix_commerce_listings_country_district_status", "country_code", "district", "status"),
        Index("ix_commerce_listings_product_code_status", "product_code", "status"),
        {"schema": "commerce"},
    )

    seller_farmer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.farmer_profiles.id", ondelete="CASCADE"),
        nullable=False,
    )
    field_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("farm.fields.id", ondelete="SET NULL"), nullable=True
    )
    crop_cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.crop_cycles.id", ondelete="SET NULL"),
        nullable=True,
    )

    listing_kind: Mapped[str] = mapped_column(String(16), nullable=False)
    product_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    product_name: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    quantity_total: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False)
    quantity_available: Mapped[Decimal] = mapped_column(Numeric(18, 3), nullable=False)
    quantity_unit: Mapped[str] = mapped_column(String(8), nullable=False)

    asking_price_minor: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)

    grade: Mapped[str | None] = mapped_column(String(80), nullable=True)
    harvest_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    available_from: Mapped[date | None] = mapped_column(Date, nullable=True)
    delivery_mode: Mapped[str] = mapped_column(String(16), nullable=False)

    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    region: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
    upazila: Mapped[str | None] = mapped_column(String(120), nullable=True)

    attributes: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False, default=dict)

    status: Mapped[str] = mapped_column(String(16), nullable=False, default=ListingStatus.ACTIVE.value)
