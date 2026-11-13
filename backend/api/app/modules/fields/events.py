"""Field domain events, appended to the outbox with the state change."""

import uuid

from app.shared.events import AggregateType, DomainEvent, EventType


def field_created(
    *,
    field_id: uuid.UUID,
    farmer_id: uuid.UUID,
    country_code: str,
    area_sq_m: float,
    centroid_longitude: float,
    centroid_latitude: float,
) -> DomainEvent:
    """Consumed later by earth-observation scheduling and farm memory."""
    return DomainEvent(
        event_type=EventType.FIELD_CREATED,
        aggregate_type=AggregateType.FIELD,
        aggregate_id=field_id,
        payload={
            "farmer_id": str(farmer_id),
            "country_code": country_code,
            "area_sq_m": area_sq_m,
            "centroid": {
                "longitude": centroid_longitude,
                "latitude": centroid_latitude,
            },
        },
    )


def field_updated(*, field_id: uuid.UUID, changed_fields: list[str]) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.FIELD_UPDATED,
        aggregate_type=AggregateType.FIELD,
        aggregate_id=field_id,
        payload={"changed_fields": changed_fields},
    )


def field_archived(*, field_id: uuid.UUID) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.FIELD_ARCHIVED,
        aggregate_type=AggregateType.FIELD,
        aggregate_id=field_id,
        payload={},
    )
