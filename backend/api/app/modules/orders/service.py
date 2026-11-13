"""Order business logic.

Order *creation* happens inside `BiddingService.accept_bid`'s single
transaction, not here - this service owns reads and the total-amount
rounding rule so both `bidding/service.py` and any future caller compute
money the exact same way.
"""

import uuid
from datetime import datetime
from decimal import ROUND_HALF_UP, Decimal

from app.modules.orders import policies
from app.modules.orders.exceptions import OrderNotFoundError
from app.modules.orders.repository import OrderRepository, OrderWithContext

ROUNDING_RULE = (
    "total_amount_minor = round(quantity * unit_price_minor), ROUND_HALF_UP "
    "to the nearest whole minor unit (e.g. BDT 0.5 paisa rounds up to 1 paisa)."
)


def compute_total_amount_minor(*, quantity: Decimal, unit_price_minor: int) -> int:
    """The one place order totals are computed - see `ROUNDING_RULE`.
    Never a float: `quantity` is already a `Decimal` column value and
    `unit_price_minor` is an integer minor-unit price."""
    exact = quantity * Decimal(unit_price_minor)
    return int(exact.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


class OrderService:
    def __init__(self, repository: OrderRepository) -> None:
        self._repository = repository

    async def get_order(
        self,
        *,
        order_id: uuid.UUID,
        farmer_id: uuid.UUID | None,
        buyer_id: uuid.UUID | None,
        role_codes: set[str],
    ) -> OrderWithContext:
        record = await self._repository.get_by_id_with_context(order_id)
        if record is None:
            raise OrderNotFoundError(f"Order {order_id} not found")

        if not policies.can_view_order(
            order=record.order, farmer_id=farmer_id, buyer_id=buyer_id, role_codes=role_codes
        ):
            # 404 rather than 403: order ids must not be probeable.
            raise OrderNotFoundError(f"Order {order_id} not found")

        return record

    async def list_orders(
        self,
        *,
        farmer_id: uuid.UUID | None,
        buyer_id: uuid.UUID | None,
        role: str | None,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None,
        status_filter: str | None,
    ) -> list[OrderWithContext]:
        seller_filter = farmer_id if role in (None, "SELLER") else None
        buyer_filter = buyer_id if role in (None, "BUYER") else None
        return await self._repository.list_for_seller_or_buyer(
            seller_farmer_id=seller_filter,
            buyer_id=buyer_filter,
            limit=limit,
            cursor=cursor,
            status_filter=status_filter,
        )
