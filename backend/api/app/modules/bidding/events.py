"""Bid domain events, appended to the outbox with the state change."""

import uuid
from decimal import Decimal

from app.shared.events import AggregateType, DomainEvent, EventType


def bid_placed(
    *,
    bid_id: uuid.UUID,
    listing_id: uuid.UUID,
    buyer_id: uuid.UUID,
    quantity: Decimal,
    unit_price_minor: int,
    currency: str,
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.BID_PLACED,
        aggregate_type=AggregateType.BID,
        aggregate_id=bid_id,
        payload={
            "listing_id": str(listing_id),
            "buyer_id": str(buyer_id),
            "quantity": str(quantity),
            "unit_price_minor": unit_price_minor,
            "currency": currency,
        },
    )


def bid_withdrawn(*, bid_id: uuid.UUID, listing_id: uuid.UUID) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.BID_WITHDRAWN,
        aggregate_type=AggregateType.BID,
        aggregate_id=bid_id,
        payload={"listing_id": str(listing_id)},
    )


def bid_accepted(*, bid_id: uuid.UUID, listing_id: uuid.UUID, order_id: uuid.UUID) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.BID_ACCEPTED,
        aggregate_type=AggregateType.BID,
        aggregate_id=bid_id,
        payload={"listing_id": str(listing_id), "order_id": str(order_id)},
    )


def bid_rejected(*, bid_id: uuid.UUID, listing_id: uuid.UUID, reason: str) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.BID_REJECTED,
        aggregate_type=AggregateType.BID,
        aggregate_id=bid_id,
        payload={"listing_id": str(listing_id), "reason": reason},
    )
