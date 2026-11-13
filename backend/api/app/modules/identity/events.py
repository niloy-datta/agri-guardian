"""Identity domain events."""

import uuid

from app.shared.events import AggregateType, DomainEvent, EventType


def user_registered(
    *, user_id: uuid.UUID, auth_subject: str, email: str | None
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.USER_REGISTERED,
        aggregate_type=AggregateType.USER,
        aggregate_id=user_id,
        payload={"auth_subject": auth_subject, "email": email},
    )
