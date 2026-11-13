"""Authorization rules for bids."""

import uuid

from app.modules.bidding.models import Bid
from app.shared.enums import RoleCode


def can_withdraw_bid(*, bid: Bid, buyer_id: uuid.UUID, role_codes: set[str]) -> bool:
    if bid.buyer_id == buyer_id:
        return True
    return RoleCode.ADMIN in role_codes


def can_accept_bid(*, listing_seller_farmer_id: uuid.UUID, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    if listing_seller_farmer_id == farmer_id:
        return True
    return RoleCode.ADMIN in role_codes
