"""Indexes

Every non-constraint index in the database, defined in one place so the
names match `__table_args__` in the ORM models exactly and `alembic check`
can prove it.

Three kinds matter here:

- GiST on `farm.fields.boundary`/`centroid`: without them every spatial
  query (which scenes cover this field, which fields are within N km)
  degrades to a sequential scan over full polygons.
- Composite `(parent_id, created_at, id)`: these back the keyset
  pagination in the field and crop-cycle repositories, so a page is an
  index range scan rather than a sort of the farmer's whole history.
- A partial index on pending outbox rows: the drain query only ever looks
  at PENDING, and this keeps the index small as processed rows accumulate.

Revision ID: 009_indexes
Revises: 008_platform_foundation
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "009_indexes"
down_revision: str | None = "008_platform_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- identity ---
    op.create_index("ix_identity_users_email", "users", ["email"], schema="identity")
    op.create_index("ix_identity_users_phone", "users", ["phone"], schema="identity")
    op.create_index(
        "ix_identity_user_roles_user_id", "user_roles", ["user_id"], schema="identity"
    )

    # --- farm ---
    op.create_index(
        "ix_farm_farmer_profiles_country",
        "farmer_profiles",
        ["country_code"],
        schema="farm",
    )
    op.create_index(
        "ix_farm_fields_boundary_gist",
        "fields",
        ["boundary"],
        schema="farm",
        postgresql_using="gist",
    )
    op.create_index(
        "ix_farm_fields_centroid_gist",
        "fields",
        ["centroid"],
        schema="farm",
        postgresql_using="gist",
    )
    op.create_index(
        "ix_farm_fields_farmer_created",
        "fields",
        ["farmer_id", "created_at", "id"],
        schema="farm",
    )
    op.create_index(
        "ix_farm_fields_country_region",
        "fields",
        ["country_code", "region"],
        schema="farm",
    )
    op.create_index(
        "ix_farm_crop_cycles_field_created",
        "crop_cycles",
        ["field_id", "created_at", "id"],
        schema="farm",
    )
    op.create_index(
        "ix_farm_crop_cycles_status", "crop_cycles", ["status"], schema="farm"
    )

    # --- platform ---
    op.create_index(
        "ix_platform_outbox_events_pending",
        "outbox_events",
        ["occurred_at"],
        schema="platform",
        postgresql_where=sa.text("status = 'PENDING'"),
    )
    op.create_index(
        "ix_platform_outbox_events_aggregate",
        "outbox_events",
        ["aggregate_type", "aggregate_id"],
        schema="platform",
    )
    op.create_index(
        "ix_platform_audit_logs_actor_created",
        "audit_logs",
        ["actor_user_id", "created_at"],
        schema="platform",
    )
    op.create_index(
        "ix_platform_audit_logs_entity",
        "audit_logs",
        ["entity_type", "entity_id"],
        schema="platform",
    )
    op.create_index(
        "ix_platform_idempotency_keys_expires_at",
        "idempotency_keys",
        ["expires_at"],
        schema="platform",
    )


def downgrade() -> None:
    op.drop_index(
        "ix_platform_idempotency_keys_expires_at",
        table_name="idempotency_keys",
        schema="platform",
    )
    op.drop_index(
        "ix_platform_audit_logs_entity", table_name="audit_logs", schema="platform"
    )
    op.drop_index(
        "ix_platform_audit_logs_actor_created",
        table_name="audit_logs",
        schema="platform",
    )
    op.drop_index(
        "ix_platform_outbox_events_aggregate",
        table_name="outbox_events",
        schema="platform",
    )
    op.drop_index(
        "ix_platform_outbox_events_pending",
        table_name="outbox_events",
        schema="platform",
    )

    op.drop_index("ix_farm_crop_cycles_status", table_name="crop_cycles", schema="farm")
    op.drop_index(
        "ix_farm_crop_cycles_field_created", table_name="crop_cycles", schema="farm"
    )
    op.drop_index("ix_farm_fields_country_region", table_name="fields", schema="farm")
    op.drop_index("ix_farm_fields_farmer_created", table_name="fields", schema="farm")
    op.drop_index("ix_farm_fields_centroid_gist", table_name="fields", schema="farm")
    op.drop_index("ix_farm_fields_boundary_gist", table_name="fields", schema="farm")
    op.drop_index(
        "ix_farm_farmer_profiles_country", table_name="farmer_profiles", schema="farm"
    )

    op.drop_index(
        "ix_identity_user_roles_user_id", table_name="user_roles", schema="identity"
    )
    op.drop_index("ix_identity_users_phone", table_name="users", schema="identity")
    op.drop_index("ix_identity_users_email", table_name="users", schema="identity")
