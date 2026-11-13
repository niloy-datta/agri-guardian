"""Idempotent request handling for non-repeatable POSTs.

The Flutter client queues mutations while offline and retries them when
connectivity returns. Without this, a retried "create field" would create a
second field. Callers pass an `Idempotency-Key` header; the first request
reserves the key and stores its response, later replays return the stored
response instead of re-executing.
"""

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Annotated, Any

from fastapi import Header
from sqlalchemy.exc import IntegrityError

from app.core.exceptions import ConflictError
from app.modules.admin.repository import IdempotencyRepository

DEFAULT_TTL = timedelta(hours=24)

IdempotencyKeyHeader = Annotated[
    str | None, Header(alias="Idempotency-Key", max_length=255)
]


class IdempotencyConflictError(ConflictError):
    error_code = "idempotency_conflict"


@dataclass(slots=True)
class ReplayedResponse:
    status_code: int
    body: dict


def fingerprint_request(payload: Any) -> str:
    """Stable hash of the request body.

    Reusing one key for a *different* body is a client bug, not a retry, so
    it is rejected rather than silently replaying the first response.
    """
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


class IdempotencyGuard:
    def __init__(self, repository: IdempotencyRepository) -> None:
        self._repository = repository

    async def begin(
        self,
        *,
        key: str,
        user_id: Any,
        endpoint: str,
        request_payload: Any,
        ttl: timedelta = DEFAULT_TTL,
    ) -> tuple[ReplayedResponse | None, Any]:
        """Returns `(replay, reservation)`.

        If `replay` is set, the caller must return it verbatim and skip its
        work entirely. Otherwise `reservation` must be passed to `finish`
        once the work succeeds.
        """
        fingerprint = fingerprint_request(request_payload)
        existing = await self._repository.get(key=key, user_id=user_id, endpoint=endpoint)

        if existing is not None:
            if existing.request_fingerprint != fingerprint:
                raise IdempotencyConflictError(
                    "Idempotency-Key was already used with a different request body"
                )
            if existing.response_status is None:
                # A concurrent request holds the key but has not finished yet.
                raise IdempotencyConflictError(
                    "A request with this Idempotency-Key is still in progress"
                )
            return (
                ReplayedResponse(
                    status_code=existing.response_status,
                    body=existing.response_body or {},
                ),
                None,
            )

        try:
            reservation = await self._repository.reserve(
                key=key,
                user_id=user_id,
                endpoint=endpoint,
                request_fingerprint=fingerprint,
                expires_at=datetime.now(UTC) + ttl,
            )
        except IntegrityError as exc:
            # Lost a race against a concurrent identical request.
            raise IdempotencyConflictError(
                "A request with this Idempotency-Key is already in progress"
            ) from exc

        return None, reservation

    async def finish(
        self, reservation: Any, *, status_code: int, body: dict
    ) -> None:
        if reservation is None:
            return
        await self._repository.complete(
            row_id=reservation.id, response_status=status_code, response_body=body
        )
