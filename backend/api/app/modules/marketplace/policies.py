"""Authorization rules for listings."""

import uuid

from app.modules.marketplace.models import Listing
from app.shared.enums import RoleCode


def can_write_listing(*, listing: Listing, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    if listing.seller_farmer_id == farmer_id:
        return True
    return RoleCode.ADMIN in role_codes


def can_view_bid_inbox(*, listing: Listing, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    return can_write_listing(listing=listing, farmer_id=farmer_id, role_codes=role_codes)
