"""Listing domain events, appended to the outbox with the state change."""

import uuid

from app.shared.events import AggregateType, DomainEvent, EventType


def listing_created(
    *,
    listing_id: uuid.UUID,
    seller_farmer_id: uuid.UUID,
    listing_kind: str,
    product_name: str,
    quantity_total: str,
    quantity_unit: str,
    currency: str,
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.LISTING_CREATED,
        aggregate_type=AggregateType.LISTING,
        aggregate_id=listing_id,
        payload={
            "seller_farmer_id": str(seller_farmer_id),
            "listing_kind": listing_kind,
            "product_name": product_name,
            "quantity_total": quantity_total,
            "quantity_unit": quantity_unit,
            "currency": currency,
        },
    )


def listing_closed(*, listing_id: uuid.UUID, reason: str) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.LISTING_CLOSED,
        aggregate_type=AggregateType.LISTING,
        aggregate_id=listing_id,
        payload={"reason": reason},
    )
