"""Commerce marketplace core

buyer_profiles, listings, bids, orders, inventory_reservations,
order_events - the transactional bidding/marketplace vertical slice.
Highest bid never auto-wins; the seller accepts a bid manually, which
locks the listing row, re-checks available quantity, reserves inventory,
and creates the order all in one transaction (see
`app/modules/bidding/service.py::BiddingService.accept_bid`).

Revision ID: 010_commerce_marketplace_core
Revises: 009_indexes
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "010_commerce_marketplace_core"
down_revision: str | None = "009_indexes"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA = "commerce"

# Frozen copies of app.shared.enums at the time of this migration.
LISTING_KINDS = ("CROP", "FISH")
LISTING_STATUSES = ("DRAFT", "ACTIVE", "SOLD_OUT", "CLOSED", "CANCELLED")
QUANTITY_UNITS = ("KG", "MT", "PCS")
DELIVERY_MODES = ("PICKUP", "DELIVERY", "BOTH")
BID_STATUSES = ("ACTIVE", "WITHDRAWN", "ACCEPTED", "REJECTED", "EXPIRED")
INVENTORY_RESERVATION_STATUSES = ("ACTIVE", "RELEASED", "CONSUMED")
ORDER_STATUSES = ("CONFIRMED", "CANCELLED")


def _quoted(values: tuple[str, ...]) -> str:
    return ",".join(f"'{value}'" for value in values)


def _versioned_mixin_columns() -> list[sa.Column]:
    return [
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("version", sa.Integer(), server_default="1", nullable=False),
    ]


def _unversioned_mixin_columns() -> list[sa.Column]:
    """id + created_at only - for `inventory_reservations`, which has no
    `updated_at`/`version` (it is a single-write-then-status-flip record,
    not something clients optimistically-concurrency-edit)."""
    return [
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    ]


def upgrade() -> None:
    op.create_table(
        "buyer_profiles",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("display_name", sa.String(length=160), nullable=True),
        sa.Column("business_name", sa.String(length=200), nullable=True),
        sa.Column("country_code", sa.String(length=2), nullable=True),
        sa.Column("region", sa.String(length=120), nullable=True),
        sa.Column("district", sa.String(length=120), nullable=True),
        *_versioned_mixin_columns(),
        sa.UniqueConstraint("user_id", name="uq_commerce_buyer_profiles_user_id"),
        sa.ForeignKeyConstraint(["user_id"], ["identity.users.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_buyer_profiles_country", "buyer_profiles", ["country_code"], schema=SCHEMA
    )

    op.create_table(
        "listings",
        sa.Column("seller_farmer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("field_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("listing_kind", sa.String(length=16), nullable=False),
        sa.Column("product_code", sa.String(length=64), nullable=True),
        sa.Column("product_name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("quantity_total", sa.Numeric(precision=18, scale=3), nullable=False),
        sa.Column("quantity_available", sa.Numeric(precision=18, scale=3), nullable=False),
        sa.Column("quantity_unit", sa.String(length=8), nullable=False),
        sa.Column("asking_price_minor", sa.BigInteger(), nullable=True),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("grade", sa.String(length=80), nullable=True),
        sa.Column("harvest_date", sa.Date(), nullable=True),
        sa.Column("available_from", sa.Date(), nullable=True),
        sa.Column("delivery_mode", sa.String(length=16), nullable=False),
        sa.Column("country_code", sa.String(length=2), nullable=False),
        sa.Column("region", sa.String(length=120), nullable=True),
        sa.Column("district", sa.String(length=120), nullable=True),
        sa.Column("upazila", sa.String(length=120), nullable=True),
        sa.Column("attributes", postgresql.JSONB(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        *_versioned_mixin_columns(),
        sa.CheckConstraint(
            "quantity_total > 0", name="ck_commerce_listings_quantity_total_positive"
        ),
        sa.CheckConstraint(
            "quantity_available >= 0",
            name="ck_commerce_listings_quantity_available_non_negative",
        ),
        sa.CheckConstraint(
            "quantity_available <= quantity_total",
            name="ck_commerce_listings_quantity_available_le_total",
        ),
        sa.CheckConstraint(
            "asking_price_minor IS NULL OR asking_price_minor >= 0",
            name="ck_commerce_listings_asking_price_non_negative",
        ),
        sa.CheckConstraint(
            "currency ~ '^[A-Z]{3}$'", name="ck_commerce_listings_currency_format"
        ),
        sa.CheckConstraint(
            f"listing_kind IN ({_quoted(LISTING_KINDS)})", name="ck_commerce_listings_kind"
        ),
        sa.CheckConstraint(
            f"status IN ({_quoted(LISTING_STATUSES)})", name="ck_commerce_listings_status"
        ),
        sa.CheckConstraint(
            f"quantity_unit IN ({_quoted(QUANTITY_UNITS)})",
            name="ck_commerce_listings_quantity_unit",
        ),
        sa.CheckConstraint(
            f"delivery_mode IN ({_quoted(DELIVERY_MODES)})",
            name="ck_commerce_listings_delivery_mode",
        ),
        sa.ForeignKeyConstraint(
            ["seller_farmer_id"], ["farm.farmer_profiles.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["field_id"], ["farm.fields.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["crop_cycle_id"], ["farm.crop_cycles.id"], ondelete="SET NULL"
        ),
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_listings_seller_created",
        "listings",
        ["seller_farmer_id", "created_at", "id"],
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_listings_status_created",
        "listings",
        ["status", "created_at", "id"],
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_listings_country_district_status",
        "listings",
        ["country_code", "district", "status"],
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_listings_product_code_status",
        "listings",
        ["product_code", "status"],
        schema=SCHEMA,
    )

    op.create_table(
        "bids",
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("quantity", sa.Numeric(precision=18, scale=3), nullable=False),
        sa.Column("unit_price_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        *_versioned_mixin_columns(),
        sa.CheckConstraint("quantity > 0", name="ck_commerce_bids_quantity_positive"),
        sa.CheckConstraint(
            "unit_price_minor > 0", name="ck_commerce_bids_unit_price_positive"
        ),
        sa.CheckConstraint(f"status IN ({_quoted(BID_STATUSES)})", name="ck_commerce_bids_status"),
        sa.ForeignKeyConstraint(["listing_id"], ["commerce.listings.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["buyer_id"], ["commerce.buyer_profiles.id"], ondelete="CASCADE"
        ),
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_bids_listing_created", "bids", ["listing_id", "created_at", "id"], schema=SCHEMA
    )
    op.create_index(
        "ix_commerce_bids_buyer_created", "bids", ["buyer_id", "created_at", "id"], schema=SCHEMA
    )
    op.create_index("ix_commerce_bids_listing_status", "bids", ["listing_id", "status"], schema=SCHEMA)

    op.create_table(
        "orders",
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("accepted_bid_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("seller_farmer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("quantity", sa.Numeric(precision=18, scale=3), nullable=False),
        sa.Column("quantity_unit", sa.String(length=8), nullable=False),
        sa.Column("unit_price_minor", sa.BigInteger(), nullable=False),
        sa.Column("total_amount_minor", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        *_versioned_mixin_columns(),
        sa.CheckConstraint("quantity > 0", name="ck_commerce_orders_quantity_positive"),
        sa.CheckConstraint(
            "unit_price_minor > 0", name="ck_commerce_orders_unit_price_positive"
        ),
        sa.CheckConstraint(
            "total_amount_minor >= 0", name="ck_commerce_orders_total_amount_non_negative"
        ),
        sa.CheckConstraint(
            f"status IN ({_quoted(ORDER_STATUSES)})", name="ck_commerce_orders_status"
        ),
        sa.UniqueConstraint("accepted_bid_id", name="uq_commerce_orders_accepted_bid_id"),
        sa.ForeignKeyConstraint(["listing_id"], ["commerce.listings.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["accepted_bid_id"], ["commerce.bids.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(
            ["seller_farmer_id"], ["farm.farmer_profiles.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["buyer_id"], ["commerce.buyer_profiles.id"], ondelete="RESTRICT"
        ),
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_orders_seller_created",
        "orders",
        ["seller_farmer_id", "created_at", "id"],
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_orders_buyer_created", "orders", ["buyer_id", "created_at", "id"], schema=SCHEMA
    )

    op.create_table(
        "inventory_reservations",
        sa.Column("listing_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("bid_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("order_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("quantity", sa.Numeric(precision=18, scale=3), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        *_unversioned_mixin_columns(),
        sa.CheckConstraint(
            "quantity > 0", name="ck_commerce_inventory_reservations_quantity_positive"
        ),
        sa.CheckConstraint(
            f"status IN ({_quoted(INVENTORY_RESERVATION_STATUSES)})",
            name="ck_commerce_inventory_reservations_status",
        ),
        sa.UniqueConstraint(
            "order_id", name="uq_commerce_inventory_reservations_order_id"
        ),
        sa.ForeignKeyConstraint(["listing_id"], ["commerce.listings.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["bid_id"], ["commerce.bids.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["order_id"], ["commerce.orders.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )
    op.create_index(
        "ix_commerce_inventory_reservations_listing_status",
        "inventory_reservations",
        ["listing_id", "status"],
        schema=SCHEMA,
    )

    op.create_table(
        "order_events",
        sa.Column("order_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["order_id"], ["commerce.orders.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )


def downgrade() -> None:
    op.drop_table("order_events", schema=SCHEMA)
    op.drop_table("inventory_reservations", schema=SCHEMA)
    op.drop_table("orders", schema=SCHEMA)
    op.drop_table("bids", schema=SCHEMA)
    op.drop_table("listings", schema=SCHEMA)
    op.drop_table("buyer_profiles", schema=SCHEMA)
