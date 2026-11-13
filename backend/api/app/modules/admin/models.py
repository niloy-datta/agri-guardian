"""Platform-level infrastructure tables (schema: `platform`).

These are cross-cutting rather than domain-specific, and are owned by the
admin module: the transactional outbox, the audit trail, and idempotency
keys for non-repeatable POSTs.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import OutboxStatus, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin


class OutboxEvent(Base, UUIDPrimaryKeyMixin):
    """Transactional outbox.

    Written in the same transaction as the domain state change, drained by
    the `workers.events` Celery task. Postgres is the queue here on
    purpose - no Kafka until load actually justifies it.
    """

    __tablename__ = "outbox_events"
    __table_args__ = (
        CheckConstraint(
            "status IN ('" + "','".join(values(OutboxStatus)) + "')",
            name="ck_platform_outbox_events_status",
        ),
        # Partial index: the drain query only ever looks at pending rows, and
        # this keeps the index small as processed rows accumulate.
        Index(
            "ix_platform_outbox_events_pending",
            "occurred_at",
            postgresql_where=text("status = 'PENDING'"),
        ),
        Index("ix_platform_outbox_events_aggregate", "aggregate_type", "aggregate_id"),
        {"schema": "platform"},
    )

    event_type: Mapped[str] = mapped_column(String(64), nullable=False)
    aggregate_type: Mapped[str] = mapped_column(String(64), nullable=False)
    aggregate_id: Mapped[uuid.UUID] = mapped_column(PGUUID(as_uuid=True), nullable=False)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default=OutboxStatus.PENDING.value
    )
    attempts: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AuditLog(Base, UUIDPrimaryKeyMixin):
    """Append-only record of who changed what.

    Never updated or deleted by application code; retention is handled by
    a partition/archival job later.
    """

    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_platform_audit_logs_actor_created", "actor_user_id", "created_at"),
        Index("ix_platform_audit_logs_entity", "entity_type", "entity_id"),
        {"schema": "platform"},
    )

    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="SET NULL"),
        nullable=True,
    )
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(64), nullable=False)
    entity_id: Mapped[uuid.UUID | None] = mapped_column(PGUUID(as_uuid=True), nullable=True)
    context: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class IdempotencyKey(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    """Replay protection for non-repeatable POSTs.

    A client that retries a queued offline mutation sends the same
    `Idempotency-Key`; the stored response is replayed instead of creating
    a second field, order or payment.
    """

    __tablename__ = "idempotency_keys"
    __table_args__ = (
        UniqueConstraint(
            "idempotency_key",
            "user_id",
            "endpoint",
            name="uq_platform_idempotency_keys_scope",
        ),
        Index("ix_platform_idempotency_keys_expires_at", "expires_at"),
        {"schema": "platform"},
    )

    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="CASCADE"),
        nullable=False,
    )
    endpoint: Mapped[str] = mapped_column(String(255), nullable=False)
    request_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    response_status: Mapped[int | None] = mapped_column(Integer, nullable=True)
    response_body: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
