"""Transactional outbox drain and worker health.

Domain services append to `platform.outbox_events` inside the same
transaction as the state change. This module is the consumer side.

`HANDLERS` is deliberately empty right now. Every consumer (earth
observation scheduling, risk notification, marketplace projection) lands
with its own phase. Until a handler is registered for an event type, the
drain leaves that event PENDING rather than marking it processed - an
event silently discarded because nobody was listening is worse than a
backlog, because the backlog is visible and recoverable.
"""

import asyncio
from collections.abc import Awaitable, Callable
from typing import Any

from app.core.database import ping_database, session_scope
from app.core.logging import get_logger
from app.core.redis import ping_redis
from app.modules.admin.models import OutboxEvent
from app.modules.admin.repository import OutboxRepository
from workers.celery_app import celery_app

logger = get_logger("worker.events")

EventHandler = Callable[[OutboxEvent], Awaitable[None]]

# event_type -> handler. Populated by later phases via `register_handler`.
HANDLERS: dict[str, EventHandler] = {}

DEFAULT_BATCH_SIZE = 100


def register_handler(event_type: str, handler: EventHandler) -> None:
    HANDLERS[event_type] = handler


@celery_app.task(name="workers.events.ping")
def ping() -> dict[str, Any]:
    """Worker health: really touches Postgres and Redis.

    Returned verbatim to the caller, so a scheduler or an operator can tell
    a worker that is merely running from one that can actually do work.
    """

    async def _probe() -> dict[str, Any]:
        return {
            "database": await ping_database(),
            "redis": await ping_redis(),
        }

    result = asyncio.run(_probe())
    result["healthy"] = all(result.values())
    return result


@celery_app.task(name="workers.events.drain_outbox")
def drain_outbox(limit: int = DEFAULT_BATCH_SIZE) -> dict[str, Any]:
    """Dispatches pending outbox events to their registered handlers.

    With no handlers registered this reports the backlog and claims
    nothing, so events stay PENDING and intact for the phase that will
    consume them.
    """
    return asyncio.run(_drain_outbox(limit))


async def _drain_outbox(limit: int) -> dict[str, Any]:
    async with session_scope() as session:
        repository = OutboxRepository(session)
        pending = await repository.count_pending()

        if not HANDLERS:
            logger.info("outbox_drain_skipped", pending=pending, reason="no_handlers")
            return {"pending": pending, "processed": 0, "failed": 0, "handlers": 0}

        events = await repository.claim_pending(limit=limit)

    processed = 0
    failed = 0
    for event in events:
        handler = HANDLERS.get(event.event_type)
        # Each event commits on its own so one poison message cannot roll
        # back a whole successful batch.
        async with session_scope() as session:
            repository = OutboxRepository(session)
            if handler is None:
                await repository.mark_failed(
                    event.id, f"No handler registered for {event.event_type}"
                )
                failed += 1
                continue
            try:
                await handler(event)
            except Exception as exc:  # noqa: BLE001 - recorded, then retried
                logger.warning(
                    "outbox_handler_failed",
                    event_id=str(event.id),
                    event_type=event.event_type,
                    error=str(exc),
                )
                await repository.mark_failed(event.id, str(exc))
                failed += 1
            else:
                await repository.mark_processed(event.id)
                processed += 1

    logger.info("outbox_drained", processed=processed, failed=failed)
    return {
        "pending": pending,
        "processed": processed,
        "failed": failed,
        "handlers": len(HANDLERS),
    }
