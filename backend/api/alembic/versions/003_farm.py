"""Farm tables

farmer_profiles, fields, crop_cycles.

`farm.fields.boundary` is a real EPSG:4326 POLYGON and `centroid` is a
GEOGRAPHY POINT, matching app/modules/fields/models.py exactly. Both are
declared with spatial_index=False here; their GiST indexes are created in
009 under the names the ORM expects, so GeoAlchemy2's implicit index
creation never competes with an explicitly named one.

Revision ID: 003_farm
Revises: 002_identity
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from geoalchemy2 import Geography, Geometry
from sqlalchemy.dialects import postgresql

revision: str = "003_farm"
down_revision: str | None = "002_identity"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA = "farm"

# Frozen copies of app.shared.enums at the time of this migration.
FIELD_STATUSES = ("ACTIVE", "INACTIVE", "ARCHIVED")
CROP_CYCLE_STATUSES = ("PLANNED", "ACTIVE", "HARVESTED", "FAILED", "CANCELLED")
IRRIGATION_TYPES = (
    "RAINFED",
    "FLOOD",
    "FURROW",
    "SPRINKLER",
    "DRIP",
    "MANUAL",
    "OTHER",
)


def _mixin_columns() -> list[sa.Column]:
    """The shared mixin columns, appended last as the ORM emits them."""
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


def _quoted(values: tuple[str, ...]) -> str:
    return ",".join(f"'{value}'" for value in values)


def upgrade() -> None:
    op.create_table(
        "farmer_profiles",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("display_name", sa.String(length=160), nullable=True),
        sa.Column("country_code", sa.String(length=2), nullable=False),
        sa.Column("region", sa.String(length=120), nullable=True),
        sa.Column("district", sa.String(length=120), nullable=True),
        sa.Column("upazila", sa.String(length=120), nullable=True),
        sa.Column("farming_since_year", sa.Integer(), nullable=True),
        sa.Column("primary_language", sa.String(length=10), nullable=False),
        *_mixin_columns(),
        sa.UniqueConstraint("user_id", name="uq_farm_farmer_profiles_user_id"),
        sa.ForeignKeyConstraint(["user_id"], ["identity.users.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )

    op.create_table(
        "fields",
        sa.Column("farmer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column(
            "boundary",
            Geometry(geometry_type="POLYGON", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column(
            "centroid",
            Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column("area_sq_m", sa.Numeric(precision=14, scale=2), nullable=False),
        sa.Column("country_code", sa.String(length=2), nullable=False),
        sa.Column("region", sa.String(length=120), nullable=True),
        sa.Column("district", sa.String(length=120), nullable=True),
        sa.Column("upazila", sa.String(length=120), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        *_mixin_columns(),
        sa.CheckConstraint(
            f"status IN ({_quoted(FIELD_STATUSES)})", name="ck_farm_fields_status"
        ),
        # Guards against a degenerate polygon slipping through and poisoning
        # every per-hectare calculation downstream.
        sa.CheckConstraint("area_sq_m > 0", name="ck_farm_fields_area_positive"),
        sa.ForeignKeyConstraint(
            ["farmer_id"], ["farm.farmer_profiles.id"], ondelete="CASCADE"
        ),
        schema=SCHEMA,
    )

    op.create_table(
        "crop_cycles",
        sa.Column("field_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("crop_code", sa.String(length=64), nullable=False),
        sa.Column("variety", sa.String(length=120), nullable=True),
        sa.Column("planting_date", sa.Date(), nullable=True),
        sa.Column("expected_harvest_date", sa.Date(), nullable=True),
        sa.Column("actual_harvest_date", sa.Date(), nullable=True),
        sa.Column("current_stage", sa.String(length=64), nullable=True),
        sa.Column("irrigation_type", sa.String(length=24), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        *_mixin_columns(),
        sa.CheckConstraint(
            f"status IN ({_quoted(CROP_CYCLE_STATUSES)})",
            name="ck_farm_crop_cycles_status",
        ),
        sa.CheckConstraint(
            "irrigation_type IS NULL OR irrigation_type IN "
            f"({_quoted(IRRIGATION_TYPES)})",
            name="ck_farm_crop_cycles_irrigation_type",
        ),
        sa.CheckConstraint(
            "expected_harvest_date IS NULL OR planting_date IS NULL "
            "OR expected_harvest_date >= planting_date",
            name="ck_farm_crop_cycles_harvest_after_planting",
        ),
        sa.ForeignKeyConstraint(["field_id"], ["farm.fields.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )


def downgrade() -> None:
    op.drop_table("crop_cycles", schema=SCHEMA)
    op.drop_table("fields", schema=SCHEMA)
    op.drop_table("farmer_profiles", schema=SCHEMA)
