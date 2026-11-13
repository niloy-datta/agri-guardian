"""Domain event contracts for the transactional outbox.

Services never publish to a broker directly. They append a row to
`platform.outbox_events` inside the same transaction as the state change,
and a Celery worker drains it. That keeps "state changed" and "event
emitted" atomic without two-phase commit, and lets high-load domains move
to their own service later without changing producer code.
"""

import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any


class EventType:
    """Canonical event names. Values are persisted, so never rename in place."""

    FIELD_CREATED = "FieldCreated"
    FIELD_UPDATED = "FieldUpdated"
    FIELD_ARCHIVED = "FieldArchived"
    CROP_CYCLE_STARTED = "CropCycleStarted"
    CROP_CYCLE_STATUS_CHANGED = "CropCycleStatusChanged"
    USER_REGISTERED = "UserRegistered"
    # Reserved for later phases; the producer side lands with each domain.
    RISK_DETECTED = "RiskDetected"
    RESCUE_CREATED = "RescueCreated"
    HARVEST_RECORDED = "HarvestRecorded"
    LISTING_CREATED = "ListingCreated"
    LISTING_CLOSED = "ListingClosed"
    BID_PLACED = "BidPlaced"
    BID_WITHDRAWN = "BidWithdrawn"
    BID_ACCEPTED = "BidAccepted"
    BID_REJECTED = "BidRejected"
    INVENTORY_RESERVED = "InventoryReserved"
    ORDER_CREATED = "OrderCreated"
    WASTE_LOT_CREATED = "WasteLotCreated"


class AggregateType:
    USER = "User"
    FIELD = "Field"
    CROP_CYCLE = "CropCycle"
    LISTING = "Listing"
    BID = "Bid"
    ORDER = "Order"


@dataclass(frozen=True, slots=True)
class DomainEvent:
    event_type: str
    aggregate_type: str
    aggregate_id: uuid.UUID
    payload: dict[str, Any] = field(default_factory=dict)
    occurred_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def to_outbox_values(self) -> dict[str, Any]:
        return {
            "event_type": self.event_type,
            "aggregate_type": self.aggregate_type,
            "aggregate_id": self.aggregate_id,
            "payload": self.payload,
            "occurred_at": self.occurred_at,
        }
