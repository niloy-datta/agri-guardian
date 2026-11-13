"""Farmer rotation profiles

farm.rotation_profiles - per-field crop history, irrigation access, budget,
preferred outcomes and explicit personalisation consent (dataset #4).

Revision ID: 011_rotation_profiles
Revises: 010_commerce_marketplace_core
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "011_rotation_profiles"
down_revision: str | None = "010_commerce_marketplace_core"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

IRRIGATION_ACCESS = ("none", "supplementary", "full")  # frozen copy


def upgrade() -> None:
    op.create_table(
        "rotation_profiles",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),  # fmt: skip
        sa.Column(
            "field_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("farm.fields.id", ondelete="CASCADE"),
            nullable=False,
        ),  # fmt: skip
        sa.Column(
            "farmer_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("farm.farmer_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),  # fmt: skip
        sa.Column(
            "previous_crops", postgresql.ARRAY(sa.String(40)), nullable=False, server_default="{}"
        ),  # fmt: skip
        sa.Column("irrigation_access", sa.String(20), nullable=False),
        sa.Column("budget_bdt", sa.Numeric(14, 2), nullable=True),
        sa.Column(
            "preferred_outcomes",
            postgresql.ARRAY(sa.String(30)),
            nullable=False,
            server_default="{}",
        ),  # fmt: skip
        sa.Column("consent_to_personalise", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("consent_recorded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),  # fmt: skip
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),  # fmt: skip
        sa.Column("version", sa.Integer, nullable=False, server_default="1"),
        sa.UniqueConstraint("field_id", name="uq_farm_rotation_profiles_field_id"),
        sa.CheckConstraint(
            "irrigation_access IN ('" + "','".join(IRRIGATION_ACCESS) + "')",
            name="ck_farm_rotation_profiles_irrigation",
        ),
        sa.CheckConstraint(
            "budget_bdt IS NULL OR budget_bdt >= 0", name="ck_farm_rotation_profiles_budget"
        ),  # fmt: skip
        sa.CheckConstraint(
            "consent_to_personalise = false OR consent_recorded_at IS NOT NULL",
            name="ck_farm_rotation_profiles_consent_time",
        ),
        schema="farm",
    )
    op.create_index("ix_farm_rotation_profiles_farmer_id", "rotation_profiles", ["farmer_id"],
                    schema="farm")  # fmt: skip


def downgrade() -> None:
    op.drop_index("ix_farm_rotation_profiles_farmer_id", table_name="rotation_profiles",
                  schema="farm")  # fmt: skip
    op.drop_table("rotation_profiles", schema="farm")
