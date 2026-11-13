"""Authorization rules for orders.

Ids of orders belonging to someone else are never confirmed to exist -
the router treats "not visible" and "does not exist" identically (404),
never 403, so order ids are not probeable.
"""

import uuid

from app.modules.orders.models import Order
from app.shared.enums import RoleCode


def can_view_order(
    *, order: Order, farmer_id: uuid.UUID | None, buyer_id: uuid.UUID | None, role_codes: set[str]
) -> bool:
    if farmer_id is not None and order.seller_farmer_id == farmer_id:
        return True
    if buyer_id is not None and order.buyer_id == buyer_id:
        return True
    return RoleCode.ADMIN in role_codes
