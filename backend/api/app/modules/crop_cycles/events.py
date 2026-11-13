"""Crop cycle domain events."""

import uuid

from app.shared.events import AggregateType, DomainEvent, EventType


def crop_cycle_started(
    *,
    cycle_id: uuid.UUID,
    field_id: uuid.UUID,
    crop_code: str,
    planting_date: str | None,
) -> DomainEvent:
    """Signals that a field now has a crop worth monitoring."""
    return DomainEvent(
        event_type=EventType.CROP_CYCLE_STARTED,
        aggregate_type=AggregateType.CROP_CYCLE,
        aggregate_id=cycle_id,
        payload={
            "field_id": str(field_id),
            "crop_code": crop_code,
            "planting_date": planting_date,
        },
    )


def crop_cycle_status_changed(
    *, cycle_id: uuid.UUID, field_id: uuid.UUID, old_status: str, new_status: str
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.CROP_CYCLE_STATUS_CHANGED,
        aggregate_type=AggregateType.CROP_CYCLE,
        aggregate_id=cycle_id,
        payload={
            "field_id": str(field_id),
            "old_status": old_status,
            "new_status": new_status,
        },
    )
