"""Order HTTP layer - reads only. Creation happens inside bid acceptance."""

import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import CurrentUser, DbSession, PageSize
from app.core.exceptions import ValidationAppError
from app.core.pagination import CursorPage, decode_cursor, encode_cursor
from app.modules.buyers.repository import BuyerRepository
from app.modules.farmers.repository import FarmerRepository
from app.modules.orders.repository import OrderRepository, OrderWithContext
from app.modules.orders.schemas import OrderListingSummaryOut, OrderRead
from app.modules.orders.service import OrderService
from app.shared.enums import OrderStatus

router = APIRouter(prefix="/marketplace", tags=["orders"])


def get_order_service(session: DbSession) -> OrderService:
    return OrderService(OrderRepository(session))


OrderServiceDep = Annotated[OrderService, Depends(get_order_service)]


def _to_read_model(record: OrderWithContext) -> OrderRead:
    order = record.order
    return OrderRead(
        id=order.id,
        listing_id=order.listing_id,
        listing=OrderListingSummaryOut(
            listing_id=order.listing_id,
            product_name=record.listing_product_name,
            listing_kind=record.listing_kind,
        ),
        accepted_bid_id=order.accepted_bid_id,
        seller_farmer_id=order.seller_farmer_id,
        buyer_id=order.buyer_id,
        seller_display_name=record.seller_display_name,
        buyer_display_name=record.buyer_display_name,
        quantity=order.quantity,
        quantity_unit=order.quantity_unit,
        unit_price_minor=order.unit_price_minor,
        total_amount_minor=order.total_amount_minor,
        currency=order.currency,
        status=order.status,
        created_at=order.created_at,
        updated_at=order.updated_at,
        version=order.version,
    )


@router.get("/orders", response_model=CursorPage[OrderRead])
async def list_orders(
    user: CurrentUser,
    session: DbSession,
    order_service: OrderServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
    role: Annotated[Literal["BUYER", "SELLER"] | None, Query()] = None,
    order_status: Annotated[OrderStatus | None, Query(alias="status")] = None,
) -> CursorPage[OrderRead]:
    """Orders where the caller is the seller, the buyer, or both -
    `role=BUYER`/`role=SELLER` narrows to one side only. `status`, when
    given, must be a real `OrderStatus` value (Task 9) - a 422, not a
    silently-empty page, for a typo."""
    farmer = await FarmerRepository(session).get_by_user_id(user.id)
    buyer = await BuyerRepository(session).get_by_user_id(user.id)

    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    orders = await order_service.list_orders(
        farmer_id=farmer.id if farmer else None,
        buyer_id=buyer.id if buyer else None,
        role=role,
        limit=page_size + 1,
        cursor=decoded_cursor,
        status_filter=order_status.value if order_status else None,
    )

    has_more = len(orders) > page_size
    page = orders[:page_size]
    next_cursor = (
        encode_cursor(page[-1].order.created_at, page[-1].order.id) if has_more and page else None
    )

    return CursorPage[OrderRead](
        items=[_to_read_model(record) for record in page], next_cursor=next_cursor, has_more=has_more
    )


@router.get("/orders/{order_id}", response_model=OrderRead)
async def get_order(
    order_id: uuid.UUID, user: CurrentUser, session: DbSession, order_service: OrderServiceDep
) -> OrderRead:
    farmer = await FarmerRepository(session).get_by_user_id(user.id)
    buyer = await BuyerRepository(session).get_by_user_id(user.id)

    record = await order_service.get_order(
        order_id=order_id,
        farmer_id=farmer.id if farmer else None,
        buyer_id=buyer.id if buyer else None,
        role_codes=user.role_codes,
    )
    return _to_read_model(record)
