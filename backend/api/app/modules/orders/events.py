"""Order domain events, appended to the outbox with the state change."""

import uuid

from app.shared.events import AggregateType, DomainEvent, EventType


def order_created(
    *,
    order_id: uuid.UUID,
    listing_id: uuid.UUID,
    accepted_bid_id: uuid.UUID,
    seller_farmer_id: uuid.UUID,
    buyer_id: uuid.UUID,
    total_amount_minor: int,
    currency: str,
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.ORDER_CREATED,
        aggregate_type=AggregateType.ORDER,
        aggregate_id=order_id,
        payload={
            "listing_id": str(listing_id),
            "accepted_bid_id": str(accepted_bid_id),
            "seller_farmer_id": str(seller_farmer_id),
            "buyer_id": str(buyer_id),
            "total_amount_minor": total_amount_minor,
            "currency": currency,
        },
    )


def inventory_reserved(
    *, order_id: uuid.UUID, listing_id: uuid.UUID, quantity: str
) -> DomainEvent:
    return DomainEvent(
        event_type=EventType.INVENTORY_RESERVED,
        aggregate_type=AggregateType.ORDER,
        aggregate_id=order_id,
        payload={"listing_id": str(listing_id), "quantity": quantity},
    )
