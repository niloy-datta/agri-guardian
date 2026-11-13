"""Database access for platform infrastructure tables."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.admin.models import AuditLog, IdempotencyKey, OutboxEvent
from app.shared.enums import OutboxStatus
from app.shared.events import DomainEvent


class OutboxRepository:
    """Appends and drains `platform.outbox_events`.

    `append` never commits - it participates in the caller's transaction so
    the event and the state change land together or not at all.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def append(self, event: DomainEvent) -> OutboxEvent:
        row = OutboxEvent(**event.to_outbox_values())
        self._session.add(row)
        await self._session.flush()
        return row

    async def claim_pending(self, *, limit: int = 100) -> list[OutboxEvent]:
        """Locks a batch of pending events for this worker.

        `FOR UPDATE SKIP LOCKED` lets several workers drain concurrently
        without handing the same event to two of them.
        """
        stmt = (
            select(OutboxEvent)
            .where(OutboxEvent.status == OutboxStatus.PENDING.value)
            .order_by(OutboxEvent.occurred_at)
            .limit(limit)
            .with_for_update(skip_locked=True)
        )
        result = await self._session.execute(stmt)
        events = list(result.scalars().all())

        if events:
            await self._session.execute(
                update(OutboxEvent)
                .where(OutboxEvent.id.in_([event.id for event in events]))
                .values(status=OutboxStatus.PROCESSING.value)
            )
        return events

    async def mark_processed(self, event_id: uuid.UUID) -> None:
        await self._session.execute(
            update(OutboxEvent)
            .where(OutboxEvent.id == event_id)
            .values(
                status=OutboxStatus.PROCESSED.value,
                processed_at=datetime.now(UTC),
                last_error=None,
            )
        )

    async def mark_failed(self, event_id: uuid.UUID, error: str) -> None:
        await self._session.execute(
            update(OutboxEvent)
            .where(OutboxEvent.id == event_id)
            .values(
                status=OutboxStatus.PENDING.value,
                attempts=OutboxEvent.attempts + 1,
                last_error=error[:2000],
            )
        )

    async def count_pending(self) -> int:
        from sqlalchemy import func as sa_func

        stmt = select(sa_func.count(OutboxEvent.id)).where(
            OutboxEvent.status == OutboxStatus.PENDING.value
        )
        result = await self._session.execute(stmt)
        return int(result.scalar_one())


class AuditRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def record(
        self,
        *,
        actor_user_id: uuid.UUID | None,
        action: str,
        entity_type: str,
        entity_id: uuid.UUID | None,
        context: dict | None = None,
        request_id: str | None = None,
    ) -> AuditLog:
        row = AuditLog(
            actor_user_id=actor_user_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            context=context or {},
            request_id=request_id,
        )
        self._session.add(row)
        await self._session.flush()
        return row


class IdempotencyRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(
        self, *, key: str, user_id: uuid.UUID, endpoint: str
    ) -> IdempotencyKey | None:
        stmt = select(IdempotencyKey).where(
            IdempotencyKey.idempotency_key == key,
            IdempotencyKey.user_id == user_id,
            IdempotencyKey.endpoint == endpoint,
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def reserve(
        self,
        *,
        key: str,
        user_id: uuid.UUID,
        endpoint: str,
        request_fingerprint: str,
        expires_at: datetime,
    ) -> IdempotencyKey:
        row = IdempotencyKey(
            idempotency_key=key,
            user_id=user_id,
            endpoint=endpoint,
            request_fingerprint=request_fingerprint,
            expires_at=expires_at,
        )
        self._session.add(row)
        await self._session.flush()
        return row

    async def complete(
        self, *, row_id: uuid.UUID, response_status: int, response_body: dict
    ) -> None:
        await self._session.execute(
            update(IdempotencyKey)
            .where(IdempotencyKey.id == row_id)
            .values(response_status=response_status, response_body=response_body)
        )
