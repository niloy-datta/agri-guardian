"""Domain enums shared across modules.

Stored in Postgres as VARCHAR with CHECK constraints rather than native
Postgres ENUM types: adding a value later is a cheap constraint swap
instead of a type migration that locks dependent tables.
"""

from enum import StrEnum


class RoleCode(StrEnum):
    FARMER = "FARMER"
    FISH_FARMER = "FISH_FARMER"
    BUYER = "BUYER"
    AGENT = "AGENT"
    AGRONOMIST = "AGRONOMIST"
    ADMIN = "ADMIN"
    ENTERPRISE = "ENTERPRISE"


class FieldStatus(StrEnum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    ARCHIVED = "ARCHIVED"


class CropCycleStatus(StrEnum):
    PLANNED = "PLANNED"
    ACTIVE = "ACTIVE"
    HARVESTED = "HARVESTED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class IrrigationType(StrEnum):
    RAINFED = "RAINFED"
    FLOOD = "FLOOD"
    FURROW = "FURROW"
    SPRINKLER = "SPRINKLER"
    DRIP = "DRIP"
    MANUAL = "MANUAL"
    OTHER = "OTHER"


class MeasurementSystem(StrEnum):
    METRIC = "METRIC"
    IMPERIAL = "IMPERIAL"


class OutboxStatus(StrEnum):
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    PROCESSED = "PROCESSED"
    FAILED = "FAILED"


class ListingKind(StrEnum):
    CROP = "CROP"
    FISH = "FISH"


class ListingStatus(StrEnum):
    DRAFT = "DRAFT"
    ACTIVE = "ACTIVE"
    SOLD_OUT = "SOLD_OUT"
    CLOSED = "CLOSED"
    CANCELLED = "CANCELLED"


class QuantityUnit(StrEnum):
    KG = "KG"
    MT = "MT"
    PCS = "PCS"


class DeliveryMode(StrEnum):
    PICKUP = "PICKUP"
    DELIVERY = "DELIVERY"
    BOTH = "BOTH"


class BidStatus(StrEnum):
    ACTIVE = "ACTIVE"
    WITHDRAWN = "WITHDRAWN"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"
    EXPIRED = "EXPIRED"


class InventoryReservationStatus(StrEnum):
    ACTIVE = "ACTIVE"
    RELEASED = "RELEASED"
    CONSUMED = "CONSUMED"


class OrderStatus(StrEnum):
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"


def values(enum_cls: type[StrEnum]) -> list[str]:
    """Helper for building Postgres CHECK constraints from an enum."""
    return [member.value for member in enum_cls]
