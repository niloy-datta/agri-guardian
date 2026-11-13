"""Bid HTTP layer."""

import uuid
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Request, status

from app.core.dependencies import (
    CurrentUser,
    DbSession,
    PageSize,
    get_audit_repository,
    get_outbox_repository,
    get_request_id,
)
from app.core.exceptions import ValidationAppError
from app.core.idempotency import IdempotencyGuard, IdempotencyKeyHeader
from app.core.pagination import CursorPage, decode_cursor, encode_cursor
from app.modules.admin.repository import AuditRepository, IdempotencyRepository, OutboxRepository
from app.modules.bidding.models import Bid
from app.modules.bidding.repository import (
    BidRepository,
    BidWithContext,
    decode_price_cursor,
    encode_price_cursor,
)
from app.modules.bidding.schemas import (
    BidAcceptResult,
    BidCreate,
    BidListingSummaryOut,
    BidRead,
    BuyerSummaryOut,
)
from app.modules.bidding.service import BiddingService
from app.modules.buyers.repository import BuyerRepository
from app.modules.buyers.service import BuyerService
from app.modules.farmers.repository import FarmerRepository
from app.modules.farmers.service import FarmerService
from app.modules.inventory.repository import InventoryRepository
from app.modules.inventory.service import InventoryService
from app.modules.marketplace.models import Listing
from app.modules.marketplace.repository import ListingRepository
from app.modules.orders.repository import OrderRepository

router = APIRouter(prefix="/marketplace", tags=["bidding"])


def get_bidding_service(
    session: DbSession,
    outbox: Annotated[OutboxRepository, Depends(get_outbox_repository)],
    audit: Annotated[AuditRepository, Depends(get_audit_repository)],
) -> BiddingService:
    return BiddingService(
        BidRepository(session),
        ListingRepository(session),
        OrderRepository(session),
        InventoryService(InventoryRepository(session)),
        outbox,
        audit,
    )


def get_buyer_service(session: DbSession) -> BuyerService:
    return BuyerService(BuyerRepository(session))


def get_farmer_service(session: DbSession) -> FarmerService:
    return FarmerService(FarmerRepository(session))


BiddingServiceDep = Annotated[BiddingService, Depends(get_bidding_service)]
BuyerServiceDep = Annotated[BuyerService, Depends(get_buyer_service)]
FarmerServiceDep = Annotated[FarmerService, Depends(get_farmer_service)]


def _read_from_context(record: BidWithContext) -> BidRead:
    bid = record.bid
    return BidRead(
        id=bid.id,
        listing_id=bid.listing_id,
        buyer_id=bid.buyer_id,
        buyer=BuyerSummaryOut(buyer_id=bid.buyer_id, display_name=record.buyer_display_name),
        listing=BidListingSummaryOut(
            listing_id=bid.listing_id,
            product_name=record.listing_product_name,
            listing_kind=record.listing_kind,
            quantity_unit=record.listing_quantity_unit,
            district=record.listing_district,
            status=record.listing_status,
        ),
        quantity=bid.quantity,
        unit_price_minor=bid.unit_price_minor,
        currency=bid.currency,
        note=bid.note,
        status=bid.status,
        expires_at=bid.expires_at,
        created_at=bid.created_at,
        updated_at=bid.updated_at,
        version=bid.version,
    )


def _read_from_bid_and_listing(bid: Bid, listing: Listing, buyer_display_name: str | None) -> BidRead:
    return BidRead(
        id=bid.id,
        listing_id=bid.listing_id,
        buyer_id=bid.buyer_id,
        buyer=BuyerSummaryOut(buyer_id=bid.buyer_id, display_name=buyer_display_name),
        listing=BidListingSummaryOut(
            listing_id=listing.id,
            product_name=listing.product_name,
            listing_kind=listing.listing_kind,
            quantity_unit=listing.quantity_unit,
            district=listing.district,
            status=listing.status,
        ),
        quantity=bid.quantity,
        unit_price_minor=bid.unit_price_minor,
        currency=bid.currency,
        note=bid.note,
        status=bid.status,
        expires_at=bid.expires_at,
        created_at=bid.created_at,
        updated_at=bid.updated_at,
        version=bid.version,
    )


@router.post(
    "/listings/{listing_id}/bids", response_model=BidRead, status_code=status.HTTP_201_CREATED
)
async def place_bid(
    listing_id: uuid.UUID,
    payload: BidCreate,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    bidding_service: BiddingServiceDep,
    buyer_service: BuyerServiceDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> BidRead:
    """Buyer is always derived from the authenticated user - the request
    schema has no `buyer_id` field for a client to set."""
    buyer = await buyer_service.ensure_profile_for_user(user_id=user.id)

    # Only used to reject a self-bid (Task 15/20) - never creates a
    # farmer profile as a side effect of placing a bid.
    farmer_repository = FarmerRepository(session)
    own_farmer_profile = await farmer_repository.get_by_user_id(user.id)

    guard: IdempotencyGuard | None = None
    reservation = None
    if idempotency_key:
        guard = IdempotencyGuard(IdempotencyRepository(session))
        replay, reservation = await guard.begin(
            key=idempotency_key,
            user_id=user.id,
            endpoint=f"POST /marketplace/listings/{listing_id}/bids",
            request_payload=payload.model_dump(mode="json"),
        )
        if replay is not None:
            return BidRead.model_validate(replay.body)

    bid, listing = await bidding_service.place_bid(
        listing_id=listing_id,
        buyer_id=buyer.id,
        seller_farmer_id_of_buyer=own_farmer_profile.id if own_farmer_profile else None,
        actor_user_id=user.id,
        quantity=payload.quantity,
        unit_price_minor=payload.unit_price_minor,
        currency=payload.currency,
        note=payload.note,
        expires_at=payload.expires_at,
        request_id=get_request_id(request),
    )

    response = _read_from_bid_and_listing(bid, listing, buyer.display_name)
    if guard is not None:
        await guard.finish(
            reservation, status_code=status.HTTP_201_CREATED, body=response.model_dump(mode="json")
        )
    return response


@router.get("/listings/{listing_id}/bids", response_model=CursorPage[BidRead])
async def seller_bid_inbox(
    listing_id: uuid.UUID,
    user: CurrentUser,
    bidding_service: BiddingServiceDep,
    farmer_service: FarmerServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
    sort: Annotated[Literal["price_desc"] | None, Query()] = None,
) -> CursorPage[BidRead]:
    """Seller-only. `sort=price_desc` reorders the list but never labels
    any entry a "winner" - the seller still chooses manually (Task 22).
    An unrecognized `sort` value is a 422 (Task 9), not a silent
    fallback to the default order."""
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)
    order_by_price_desc = sort == "price_desc"

    decoded_cursor = None
    decoded_price_cursor = None
    if cursor:
        try:
            if order_by_price_desc:
                decoded_price_cursor = decode_price_cursor(cursor)
            else:
                decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    bids = await bidding_service.list_bids_for_listing(
        listing_id=listing_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        limit=page_size + 1,
        cursor=decoded_cursor,
        price_cursor=decoded_price_cursor,
        order_by_price_desc=order_by_price_desc,
    )

    has_more = len(bids) > page_size
    page = bids[:page_size]
    next_cursor = None
    if has_more and page:
        last = page[-1].bid
        next_cursor = (
            encode_price_cursor(last.unit_price_minor, last.created_at, last.id)
            if order_by_price_desc
            else encode_cursor(last.created_at, last.id)
        )

    return CursorPage[BidRead](
        items=[_read_from_context(record) for record in page], next_cursor=next_cursor, has_more=has_more
    )


@router.get("/my-bids", response_model=CursorPage[BidRead])
async def my_bids(
    user: CurrentUser,
    bidding_service: BiddingServiceDep,
    buyer_service: BuyerServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
) -> CursorPage[BidRead]:
    buyer = await buyer_service.ensure_profile_for_user(user_id=user.id)

    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    bids = await bidding_service.list_my_bids(
        buyer_id=buyer.id, limit=page_size + 1, cursor=decoded_cursor
    )

    has_more = len(bids) > page_size
    page = bids[:page_size]
    next_cursor = (
        encode_cursor(page[-1].bid.created_at, page[-1].bid.id) if has_more and page else None
    )

    return CursorPage[BidRead](
        items=[_read_from_context(record) for record in page], next_cursor=next_cursor, has_more=has_more
    )


@router.post("/bids/{bid_id}/withdraw", response_model=BidRead)
async def withdraw_bid(
    bid_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    bidding_service: BiddingServiceDep,
    buyer_service: BuyerServiceDep,
) -> BidRead:
    buyer = await buyer_service.ensure_profile_for_user(user_id=user.id)
    bid, listing = await bidding_service.withdraw_bid(
        bid_id=bid_id,
        buyer_id=buyer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        request_id=get_request_id(request),
    )
    return _read_from_bid_and_listing(bid, listing, buyer.display_name)


@router.post("/bids/{bid_id}/accept", response_model=BidAcceptResult)
async def accept_bid(
    bid_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    bidding_service: BiddingServiceDep,
    farmer_service: FarmerServiceDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> BidAcceptResult:
    """Seller-only. This is the one transaction the whole module exists
    for - see `BiddingService.accept_bid`. Safe to retry with an
    `Idempotency-Key`: a replayed request never creates a second order."""
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    guard: IdempotencyGuard | None = None
    reservation = None
    if idempotency_key:
        guard = IdempotencyGuard(IdempotencyRepository(session))
        replay, reservation = await guard.begin(
            key=idempotency_key,
            user_id=user.id,
            endpoint=f"POST /marketplace/bids/{bid_id}/accept",
            request_payload={},
        )
        if replay is not None:
            return BidAcceptResult.model_validate(replay.body)

    bid, order, listing = await bidding_service.accept_bid(
        bid_id=bid_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        request_id=get_request_id(request),
    )
    buyer_profile = await BuyerRepository(session).get_by_id(bid.buyer_id)

    response = BidAcceptResult(
        bid=_read_from_bid_and_listing(
            bid, listing, buyer_profile.display_name if buyer_profile else None
        ),
        order_id=order.id,
    )
    if guard is not None:
        await guard.finish(
            reservation, status_code=status.HTTP_200_OK, body=response.model_dump(mode="json")
        )
    return response
