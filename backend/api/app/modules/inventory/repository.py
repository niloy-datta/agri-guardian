"""Database access for inventory reservations."""

import uuid
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.inventory.models import InventoryReservation
from app.shared.enums import InventoryReservationStatus


class InventoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        listing_id: uuid.UUID,
        bid_id: uuid.UUID,
        order_id: uuid.UUID,
        quantity: Decimal,
    ) -> InventoryReservation:
        reservation = InventoryReservation(
            listing_id=listing_id,
            bid_id=bid_id,
            order_id=order_id,
            quantity=quantity,
            status=InventoryReservationStatus.ACTIVE.value,
        )
        self._session.add(reservation)
        await self._session.flush()
        return reservation
