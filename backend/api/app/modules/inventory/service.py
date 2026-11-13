"""Inventory reservation business logic.

Deliberately thin: the actual inventory decrement lives on
`ListingRepository.decrement_available` because it is a column on the
listing row itself, locked and updated in the same statement group as the
rest of the accept-bid transaction. This service only creates the
reservation record that proves *why* a given quantity was decremented.
"""

import uuid
from decimal import Decimal

from app.modules.inventory.models import InventoryReservation
from app.modules.inventory.repository import InventoryRepository


class InventoryService:
    def __init__(self, repository: InventoryRepository) -> None:
        self._repository = repository

    async def reserve(
        self,
        *,
        listing_id: uuid.UUID,
        bid_id: uuid.UUID,
        order_id: uuid.UUID,
        quantity: Decimal,
    ) -> InventoryReservation:
        return await self._repository.create(
            listing_id=listing_id, bid_id=bid_id, order_id=order_id, quantity=quantity
        )
