"""Bidding business logic - including the one transaction that matters
most in this phase: bid acceptance.

Every service method here participates in the caller's request-scoped
session (`app.core.database.get_db`): nothing calls `session.commit()`
itself, so a raised exception anywhere in `accept_bid` rolls back every
statement it already issued, and a clean return commits them all together.
"""

import uuid
from datetime import UTC, datetime
from decimal import Decimal

from app.modules.admin.repository import AuditRepository, OutboxRepository
from app.modules.bidding import events, policies
from app.modules.bidding.exceptions import (
    BidAccessDeniedError,
    BidExpiredError,
    BidNotActiveError,
    BidNotFoundError,
    CurrencyMismatchError,
    InsufficientBidQuantityError,
    OwnListingBidError,
)
from app.modules.bidding.models import Bid
from app.modules.bidding.repository import BidRepository, BidWithContext
from app.modules.inventory.exceptions import InsufficientInventoryError
from app.modules.inventory.service import InventoryService
from app.modules.marketplace import policies as listing_policies
from app.modules.marketplace.exceptions import (
    ListingAccessDeniedError,
    ListingNotActiveError,
    ListingNotFoundError,
)
from app.modules.marketplace.models import Listing
from app.modules.marketplace.repository import ListingRepository
from app.modules.orders import events as order_events
from app.modules.orders.models import Order
from app.modules.orders.repository import OrderRepository
from app.modules.orders.service import compute_total_amount_minor
from app.shared.enums import BidStatus, ListingStatus


class BiddingService:
    def __init__(
        self,
        bid_repository: BidRepository,
        listing_repository: ListingRepository,
        order_repository: OrderRepository,
        inventory_service: InventoryService,
        outbox: OutboxRepository,
        audit: AuditRepository,
    ) -> None:
        self._bids = bid_repository
        self._listings = listing_repository
        self._orders = order_repository
        self._inventory = inventory_service
        self._outbox = outbox
        self._audit = audit

    async def place_bid(
        self,
        *,
        listing_id: uuid.UUID,
        buyer_id: uuid.UUID,
        seller_farmer_id_of_buyer: uuid.UUID | None,
        actor_user_id: uuid.UUID,
        quantity: Decimal,
        unit_price_minor: int,
        currency: str,
        note: str | None,
        expires_at: datetime | None,
        request_id: str | None = None,
    ) -> tuple[Bid, Listing]:
        listing = await self._listings.get_by_id(listing_id)
        if listing is None:
            raise ListingNotFoundError(f"Listing {listing_id} not found")

        if listing.status != ListingStatus.ACTIVE.value:
            raise ListingNotActiveError(f"Listing is {listing.status}, not ACTIVE")

        if seller_farmer_id_of_buyer is not None and listing.seller_farmer_id == seller_farmer_id_of_buyer:
            raise OwnListingBidError("You cannot bid on your own listing")

        if currency.upper() != listing.currency:
            raise CurrencyMismatchError(
                f"Bid currency {currency} does not match listing currency {listing.currency}"
            )

        if quantity > listing.quantity_available:
            raise InsufficientBidQuantityError(
                "Bid quantity exceeds the listing's currently available quantity"
            )

        if expires_at is not None and expires_at <= datetime.now(UTC):
            raise BidExpiredError("expires_at must be in the future")

        bid = await self._bids.create(
            listing_id=listing_id,
            buyer_id=buyer_id,
            quantity=quantity,
            unit_price_minor=unit_price_minor,
            currency=currency.upper(),
            note=note,
            expires_at=expires_at,
        )

        await self._outbox.append(
            events.bid_placed(
                bid_id=bid.id,
                listing_id=listing_id,
                buyer_id=buyer_id,
                quantity=quantity,
                unit_price_minor=unit_price_minor,
                currency=bid.currency,
            )
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.bid.place",
            entity_type="commerce.bids",
            entity_id=bid.id,
            context={"listing_id": str(listing_id), "quantity": str(quantity)},
            request_id=request_id,
        )
        return bid, listing

    async def list_bids_for_listing(
        self,
        *,
        listing_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None,
        price_cursor: tuple[int, datetime, uuid.UUID] | None,
        order_by_price_desc: bool,
    ) -> list[BidWithContext]:
        listing = await self._listings.get_by_id(listing_id)
        if listing is None:
            raise ListingNotFoundError(f"Listing {listing_id} not found")

        if not listing_policies.can_view_bid_inbox(listing=listing, farmer_id=farmer_id, role_codes=role_codes):
            # 404, not 403: another farmer's bid inbox must not be probeable.
            raise ListingNotFoundError(f"Listing {listing_id} not found")

        return await self._bids.list_by_listing(
            listing_id=listing_id,
            limit=limit,
            cursor=cursor,
            price_cursor=price_cursor,
            order_by_price_desc=order_by_price_desc,
        )

    async def list_my_bids(
        self, *, buyer_id: uuid.UUID, limit: int, cursor: tuple[datetime, uuid.UUID] | None
    ) -> list[BidWithContext]:
        return await self._bids.list_by_buyer(buyer_id=buyer_id, limit=limit, cursor=cursor)

    async def withdraw_bid(
        self,
        *,
        bid_id: uuid.UUID,
        buyer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        request_id: str | None = None,
    ) -> tuple[Bid, Listing]:
        bid = await self._bids.get_by_id(bid_id)
        if bid is None:
            raise BidNotFoundError(f"Bid {bid_id} not found")

        if not policies.can_withdraw_bid(bid=bid, buyer_id=buyer_id, role_codes=role_codes):
            raise BidAccessDeniedError("You cannot withdraw this bid")

        if bid.status != BidStatus.ACTIVE.value:
            raise BidNotActiveError(f"Bid is {bid.status}, not ACTIVE - it cannot be withdrawn")

        updated = await self._bids.withdraw(bid_id=bid_id)
        if updated is None:
            raise BidNotActiveError("Bid was already withdrawn or resolved by a concurrent request")

        listing = await self._listings.get_by_id(bid.listing_id)
        assert listing is not None  # FK guarantees the listing still exists

        await self._outbox.append(events.bid_withdrawn(bid_id=bid_id, listing_id=bid.listing_id))
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.bid.withdraw",
            entity_type="commerce.bids",
            entity_id=bid_id,
            context={"listing_id": str(bid.listing_id)},
            request_id=request_id,
        )
        return updated, listing

    async def accept_bid(
        self,
        *,
        bid_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        request_id: str | None = None,
    ) -> tuple[Bid, Order, Listing]:
        """The one atomic transaction this whole module exists for.

        Lock order is always LISTING then BID (Task 26) so two concurrent
        acceptances - even against different bids on the same listing -
        can never deadlock against each other; they simply serialize on
        the listing row.
        """
        bid_preview = await self._bids.get_by_id(bid_id)
        if bid_preview is None:
            raise BidNotFoundError(f"Bid {bid_id} not found")

        listing = await self._listings.get_for_update(bid_preview.listing_id)
        if listing is None:  # pragma: no cover - FK guarantees this cannot happen
            raise ListingNotFoundError(f"Listing {bid_preview.listing_id} not found")

        bid = await self._bids.get_for_update(bid_id)
        if bid is None:  # pragma: no cover - already confirmed to exist above
            raise BidNotFoundError(f"Bid {bid_id} not found")

        if not policies.can_accept_bid(
            listing_seller_farmer_id=listing.seller_farmer_id, farmer_id=farmer_id, role_codes=role_codes
        ):
            raise ListingAccessDeniedError("You cannot accept bids on this listing")

        if listing.status != ListingStatus.ACTIVE.value:
            raise ListingNotActiveError(f"Listing is {listing.status}, not ACTIVE")

        if bid.status != BidStatus.ACTIVE.value:
            raise BidNotActiveError(f"Bid is {bid.status}, not ACTIVE")

        if bid.expires_at is not None and bid.expires_at <= datetime.now(UTC):
            raise BidExpiredError("This bid has expired and cannot be accepted")

        if bid.quantity > listing.quantity_available:
            raise InsufficientInventoryError(
                "Listing no longer has enough quantity available for this bid"
            )

        remaining = listing.quantity_available - bid.quantity
        new_status = ListingStatus.SOLD_OUT.value if remaining == 0 else None
        await self._listings.decrement_available(
            listing_id=listing.id, quantity=bid.quantity, new_status=new_status
        )

        total_amount_minor = compute_total_amount_minor(
            quantity=bid.quantity, unit_price_minor=bid.unit_price_minor
        )
        order = await self._orders.create(
            listing_id=listing.id,
            accepted_bid_id=bid.id,
            seller_farmer_id=listing.seller_farmer_id,
            buyer_id=bid.buyer_id,
            quantity=bid.quantity,
            quantity_unit=listing.quantity_unit,
            unit_price_minor=bid.unit_price_minor,
            total_amount_minor=total_amount_minor,
            currency=bid.currency,
        )

        await self._inventory.reserve(
            listing_id=listing.id, bid_id=bid.id, order_id=order.id, quantity=bid.quantity
        )
        await self._bids.mark_accepted(bid_id=bid.id)

        rejected_bid_ids: list[uuid.UUID] = []
        if new_status == ListingStatus.SOLD_OUT.value:
            rejected_bid_ids = await self._bids.reject_other_active_bids(
                listing_id=listing.id, except_bid_id=bid.id
            )

        await self._orders.append_event(
            order_id=order.id,
            event_type="marketplace.order.create",
            payload={"accepted_bid_id": str(bid.id), "listing_id": str(listing.id)},
            actor_user_id=actor_user_id,
        )

        await self._outbox.append(
            events.bid_accepted(bid_id=bid.id, listing_id=listing.id, order_id=order.id)
        )
        await self._outbox.append(
            order_events.inventory_reserved(
                order_id=order.id, listing_id=listing.id, quantity=str(bid.quantity)
            )
        )
        await self._outbox.append(
            order_events.order_created(
                order_id=order.id,
                listing_id=listing.id,
                accepted_bid_id=bid.id,
                seller_farmer_id=listing.seller_farmer_id,
                buyer_id=bid.buyer_id,
                total_amount_minor=total_amount_minor,
                currency=bid.currency,
            )
        )
        for rejected_id in rejected_bid_ids:
            await self._outbox.append(
                events.bid_rejected(
                    bid_id=rejected_id, listing_id=listing.id, reason="INVENTORY_UNAVAILABLE"
                )
            )

        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.bid.accept",
            entity_type="commerce.bids",
            entity_id=bid.id,
            context={"order_id": str(order.id), "listing_id": str(listing.id)},
            request_id=request_id,
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.order.create",
            entity_type="commerce.orders",
            entity_id=order.id,
            context={"accepted_bid_id": str(bid.id), "total_amount_minor": total_amount_minor},
            request_id=request_id,
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.inventory.reserve",
            entity_type="commerce.inventory_reservations",
            entity_id=order.id,
            context={"listing_id": str(listing.id), "quantity": str(bid.quantity)},
            request_id=request_id,
        )

        refreshed_bid = await self._bids.get_by_id(bid.id)
        assert refreshed_bid is not None  # just written above, in this same transaction
        refreshed_listing = await self._listings.get_by_id(listing.id)
        assert refreshed_listing is not None  # just updated above, in this same transaction
        return refreshed_bid, order, refreshed_listing
