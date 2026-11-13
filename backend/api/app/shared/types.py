"""ORM mixins shared by every domain model.

Every table carries `id` (UUID), `created_at`, `updated_at` and `version`
so the Flutter client can sync safely against a local Drift/SQLite store
and so optimistic concurrency works without row-level locks on reads.
"""

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Integer, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column


class UUIDPrimaryKeyMixin:
    """UUID primary keys, generated client- or server-side.

    UUIDs (not bigserial) so offline clients can mint ids locally and push
    them later without collision, and so ids stay opaque across shards.
    """

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=func.gen_random_uuid(),
    )


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class VersionMixin:
    """Optimistic concurrency counter.

    Incremented on every write. A client that queued an offline edit sends
    the version it last saw; the service rejects the write if it moved on.
    """

    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default="1")


class MoneyColumnsMixin:
    """Money is always stored as an integer minor unit plus ISO-4217 code.

    Never a float, never a bare numeric without its currency.
    """

    amount_minor: Mapped[int] = mapped_column(BigInteger, nullable=False)
    currency: Mapped[str] = mapped_column(nullable=False)
