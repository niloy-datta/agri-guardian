"""Database access for orders and their append-only event log."""

import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import Select, and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.buyers.models import BuyerProfile
from app.modules.farmers.models import FarmerProfile
from app.modules.marketplace.models import Listing
from app.modules.orders.models import Order, OrderEvent
from app.shared.enums import OrderStatus


@dataclass(slots=True)
class OrderWithContext:
    """An order plus the compact listing summary and safe counterparty
    display names the mobile client needs (Task 6) - one joined query,
    never a per-row follow-up request."""

    order: Order
    listing_product_name: str
    listing_kind: str
    seller_display_name: str | None
    buyer_display_name: str | None


class OrderRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        listing_id: uuid.UUID,
        accepted_bid_id: uuid.UUID,
        seller_farmer_id: uuid.UUID,
        buyer_id: uuid.UUID,
        quantity: Decimal,
        quantity_unit: str,
        unit_price_minor: int,
        total_amount_minor: int,
        currency: str,
    ) -> Order:
        order = Order(
            listing_id=listing_id,
            accepted_bid_id=accepted_bid_id,
            seller_farmer_id=seller_farmer_id,
            buyer_id=buyer_id,
            quantity=quantity,
            quantity_unit=quantity_unit,
            unit_price_minor=unit_price_minor,
            total_amount_minor=total_amount_minor,
            currency=currency,
            status=OrderStatus.CONFIRMED.value,
        )
        self._session.add(order)
        await self._session.flush()
        return order

    async def get_by_id(self, order_id: uuid.UUID) -> Order | None:
        stmt = select(Order).where(Order.id == order_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    def _select_with_context(self) -> Select:
        return (
            select(
                Order,
                Listing.product_name,
                Listing.listing_kind,
                FarmerProfile.display_name,
                BuyerProfile.display_name,
            )
            .join(Listing, Listing.id == Order.listing_id)
            .outerjoin(FarmerProfile, FarmerProfile.id == Order.seller_farmer_id)
            .outerjoin(BuyerProfile, BuyerProfile.id == Order.buyer_id)
        )

    @staticmethod
    def _to_record(row: Any) -> OrderWithContext:
        return OrderWithContext(
            order=row[0],
            listing_product_name=row[1],
            listing_kind=row[2],
            seller_display_name=row[3],
            buyer_display_name=row[4],
        )

    async def get_by_id_with_context(self, order_id: uuid.UUID) -> OrderWithContext | None:
        stmt = self._select_with_context().where(Order.id == order_id)
        result = await self._session.execute(stmt)
        row = result.first()
        return self._to_record(row) if row else None

    async def list_for_seller_or_buyer(
        self,
        *,
        seller_farmer_id: uuid.UUID | None,
        buyer_id: uuid.UUID | None,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
        status_filter: str | None = None,
    ) -> list[OrderWithContext]:
        conditions = []
        if seller_farmer_id is not None:
            conditions.append(Order.seller_farmer_id == seller_farmer_id)
        if buyer_id is not None:
            conditions.append(Order.buyer_id == buyer_id)
        if not conditions:
            return []
        stmt = self._select_with_context().where(or_(*conditions))
        return await self._paginate(stmt, limit=limit, cursor=cursor, status_filter=status_filter)

    async def _paginate(
        self,
        stmt: Select,
        *,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None,
        status_filter: str | None,
    ) -> list[OrderWithContext]:
        if status_filter is not None:
            stmt = stmt.where(Order.status == status_filter)
        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    Order.created_at < cursor_created_at,
                    and_(Order.created_at == cursor_created_at, Order.id < cursor_id),
                )
            )
        stmt = stmt.order_by(Order.created_at.desc(), Order.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def append_event(
        self,
        *,
        order_id: uuid.UUID,
        event_type: str,
        payload: dict[str, Any],
        actor_user_id: uuid.UUID | None = None,
    ) -> OrderEvent:
        event = OrderEvent(
            order_id=order_id, event_type=event_type, payload=payload, actor_user_id=actor_user_id
        )
        self._session.add(event)
        await self._session.flush()
        return event
