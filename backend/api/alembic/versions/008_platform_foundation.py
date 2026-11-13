"""Platform tables

outbox_events, audit_logs, idempotency_keys.

Cross-cutting infrastructure rather than a domain: the transactional
outbox that makes "state changed" and "event emitted" atomic, the
append-only audit trail, and the idempotency keys that stop a retried
offline mutation from creating a second row.

Revision ID: 008_platform_foundation
Revises: 007_operations_foundation
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "008_platform_foundation"
down_revision: str | None = "007_operations_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SCHEMA = "platform"

OUTBOX_STATUSES = ("PENDING", "PROCESSING", "PROCESSED", "FAILED")


def _id_column() -> sa.Column:
    return sa.Column(
        "id",
        postgresql.UUID(as_uuid=True),
        primary_key=True,
        server_default=sa.text("gen_random_uuid()"),
        nullable=False,
    )


def _timestamp_column(name: str) -> sa.Column:
    return sa.Column(
        name,
        sa.DateTime(timezone=True),
        server_default=sa.text("now()"),
        nullable=False,
    )


def upgrade() -> None:
    op.create_table(
        "outbox_events",
        sa.Column("event_type", sa.String(length=64), nullable=False),
        sa.Column("aggregate_type", sa.String(length=64), nullable=False),
        sa.Column("aggregate_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("attempts", sa.SmallInteger(), nullable=False),
        sa.Column("last_error", sa.Text(), nullable=True),
        _timestamp_column("occurred_at"),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        _id_column(),
        sa.CheckConstraint(
            "status IN (" + ",".join(f"'{s}'" for s in OUTBOX_STATUSES) + ")",
            name="ck_platform_outbox_events_status",
        ),
        schema=SCHEMA,
    )

    op.create_table(
        "audit_logs",
        # SET NULL, not CASCADE: deleting a user must not erase the record
        # of what they did.
        sa.Column("actor_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("entity_type", sa.String(length=64), nullable=False),
        sa.Column("entity_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("context", postgresql.JSONB(), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        _timestamp_column("created_at"),
        _id_column(),
        sa.ForeignKeyConstraint(
            ["actor_user_id"], ["identity.users.id"], ondelete="SET NULL"
        ),
        schema=SCHEMA,
    )

    op.create_table(
        "idempotency_keys",
        sa.Column("idempotency_key", sa.String(length=255), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("endpoint", sa.String(length=255), nullable=False),
        sa.Column("request_fingerprint", sa.String(length=64), nullable=False),
        sa.Column("response_status", sa.Integer(), nullable=True),
        sa.Column("response_body", postgresql.JSONB(), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        _id_column(),
        _timestamp_column("created_at"),
        _timestamp_column("updated_at"),
        # The uniqueness that makes a replayed request detectable: one key
        # per user per endpoint.
        sa.UniqueConstraint(
            "idempotency_key",
            "user_id",
            "endpoint",
            name="uq_platform_idempotency_keys_scope",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["identity.users.id"], ondelete="CASCADE"),
        schema=SCHEMA,
    )


def downgrade() -> None:
    op.drop_table("idempotency_keys", schema=SCHEMA)
    op.drop_table("audit_logs", schema=SCHEMA)
    op.drop_table("outbox_events", schema=SCHEMA)
