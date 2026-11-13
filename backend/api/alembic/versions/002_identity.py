"""Identity tables

users, profiles, roles, user_roles.

No credential material is stored: `identity.users` mirrors the auth
provider's subject so domain tables have a stable foreign key. Indexes for
these tables are created in 009 so every index in the database has one
authoritative definition site.

Column order follows the ORM models, where the shared mixin columns
(`id`, `created_at`, `updated_at`, `version`) come after the table's own
columns - so a table built by this migration is byte-for-byte the table
SQLAlchemy would emit.

Revision ID: 002_identity
Revises: 001_extensions_and_schemas
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "002_identity"
down_revision: str | None = "001_extensions_and_schemas"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA = "identity"

# Frozen copies of app.shared.enums at the time of this migration: a
# migration must not change meaning when an enum is extended later.
ROLE_CODES = (
    "FARMER",
    "FISH_FARMER",
    "BUYER",
    "AGENT",
    "AGRONOMIST",
    "ADMIN",
    "ENTERPRISE",
)
MEASUREMENT_SYSTEMS = ("METRIC", "IMPERIAL")


def _mixin_columns(*, versioned: bool) -> list[sa.Column]:
    columns = [
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
    if versioned:
        columns.append(
            sa.Column("version", sa.Integer(), server_default="1", nullable=False)
        )
    return columns


def _quoted(values: tuple[str, ...]) -> str:
    return ",".join(f"'{value}'" for value in values)


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("auth_subject", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=True),
        sa.Column("phone", sa.String(length=32), nullable=True),
        sa.Column("country_code", sa.String(length=2), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        *_mixin_columns(versioned=True),
        sa.UniqueConstraint("auth_subject", name="uq_identity_users_auth_subject"),
        schema=SCHEMA,
    )

    op.create_table(
        "profiles",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("display_name", sa.String(length=160), nullable=True),
        sa.Column("avatar_storage_key", sa.String(length=512), nullable=True),
        sa.Column("language", sa.String(length=10), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
        sa.Column("measurement_system", sa.String(length=16), nullable=False),
        sa.Column("preferred_currency", sa.String(length=3), nullable=True),
        *_mixin_columns(versioned=True),
        sa.UniqueConstraint("user_id", name="uq_identity_profiles_user_id"),
        sa.CheckConstraint(
            f"measurement_system IN ({_quoted(MEASUREMENT_SYSTEMS)})",
            name="ck_identity_profiles_measurement_system",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["identity.users.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )

    op.create_table(
        "roles",
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("description", sa.String(length=255), nullable=True),
        *_mixin_columns(versioned=False),
        sa.UniqueConstraint("code", name="uq_identity_roles_code"),
        sa.CheckConstraint(
            f"code IN ({_quoted(ROLE_CODES)})", name="ck_identity_roles_code"
        ),
        schema=SCHEMA,
    )

    op.create_table(
        "user_roles",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role_id", postgresql.UUID(as_uuid=True), nullable=False),
        *_mixin_columns(versioned=False),
        sa.UniqueConstraint(
            "user_id", "role_id", name="uq_identity_user_roles_user_role"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["identity.users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["role_id"], ["identity.roles.id"], ondelete="RESTRICT"
        ),
        schema=SCHEMA,
    )

    # Roles are reference data, not sample data: `identity.user_roles`
    # foreign-keys to this table, so role assignment cannot work until the
    # code list exists. The set is fixed by the CHECK constraint above.
    op.execute(
        "INSERT INTO identity.roles (code) VALUES "
        + ",".join(f"('{code}')" for code in ROLE_CODES)
        + " ON CONFLICT (code) DO NOTHING"
    )


def downgrade() -> None:
    op.drop_table("user_roles", schema=SCHEMA)
    op.drop_table("roles", schema=SCHEMA)
    op.drop_table("profiles", schema=SCHEMA)
    op.drop_table("users", schema=SCHEMA)
