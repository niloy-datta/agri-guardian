"""Listing HTTP layer."""

import uuid
from datetime import UTC, date, datetime
from typing import Annotated

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
from app.modules.crop_cycles.repository import CropCycleRepository
from app.modules.farmers.repository import FarmerRepository
from app.modules.farmers.service import FarmerService
from app.modules.fields.repository import FieldRepository
from app.modules.marketplace.repository import ListingRepository, ListingWithSeller
from app.modules.marketplace.schemas import ListingCreate, ListingRead, SellerSummaryOut
from app.modules.marketplace.service import ListingService
from app.shared.enums import ListingKind, ListingStatus

router = APIRouter(prefix="/marketplace", tags=["marketplace"])


def get_listing_service(
    session: DbSession,
    outbox: Annotated[OutboxRepository, Depends(get_outbox_repository)],
    audit: Annotated[AuditRepository, Depends(get_audit_repository)],
) -> ListingService:
    return ListingService(
        ListingRepository(session),
        outbox,
        audit,
        FieldRepository(session),
        CropCycleRepository(session),
    )


def get_farmer_service(session: DbSession) -> FarmerService:
    return FarmerService(FarmerRepository(session))


ListingServiceDep = Annotated[ListingService, Depends(get_listing_service)]
FarmerServiceDep = Annotated[FarmerService, Depends(get_farmer_service)]


def _is_future_harvest(*, harvest_date: date | None, available_from: date | None) -> bool:
    """Task 7's exact rule: a listing is future-harvest when the more
    specific of the two declared dates is actually after today (server
    UTC date) - never merely "both fields are present".

    `available_from` is the more specific signal (it says exactly when
    the produce becomes available), so it wins when both are set. When
    only `harvest_date` is given, that is the best available signal.
    A listing with neither date, or with only past/today dates, is not
    future-harvest - it is presumed already available.
    """
    today = datetime.now(UTC).date()
    if available_from is not None:
        return available_from > today
    if harvest_date is not None:
        return harvest_date > today
    return False


def _to_read_model(record: ListingWithSeller) -> ListingRead:
    listing = record.listing
    return ListingRead(
        id=listing.id,
        seller_farmer_id=listing.seller_farmer_id,
        seller=SellerSummaryOut(
            farmer_id=listing.seller_farmer_id, display_name=record.seller_display_name
        ),
        field_id=listing.field_id,
        crop_cycle_id=listing.crop_cycle_id,
        listing_kind=listing.listing_kind,
        product_code=listing.product_code,
        product_name=listing.product_name,
        description=listing.description,
        quantity_total=listing.quantity_total,
        quantity_available=listing.quantity_available,
        quantity_unit=listing.quantity_unit,
        asking_price_minor=listing.asking_price_minor,
        currency=listing.currency,
        grade=listing.grade,
        harvest_date=listing.harvest_date,
        available_from=listing.available_from,
        is_future_harvest=_is_future_harvest(
            harvest_date=listing.harvest_date, available_from=listing.available_from
        ),
        delivery_mode=listing.delivery_mode,
        country_code=listing.country_code,
        region=listing.region,
        district=listing.district,
        upazila=listing.upazila,
        attributes=listing.attributes,
        status=listing.status,
        created_at=listing.created_at,
        updated_at=listing.updated_at,
        version=listing.version,
    )


@router.post("/listings", response_model=ListingRead, status_code=status.HTTP_201_CREATED)
async def create_listing(
    payload: ListingCreate,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    listing_service: ListingServiceDep,
    farmer_service: FarmerServiceDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> ListingRead:
    """Seller is always derived from the authenticated user - a client
    can never set `seller_farmer_id` because the request schema has no
    such field at all. `field_id`/`crop_cycle_id`, if supplied, are
    verified to belong to this seller before the listing is created
    (Task 1/2)."""
    farmer = await farmer_service.ensure_profile_for_user(
        user_id=user.id, country_code=payload.country_code
    )

    guard: IdempotencyGuard | None = None
    reservation = None
    if idempotency_key:
        guard = IdempotencyGuard(IdempotencyRepository(session))
        replay, reservation = await guard.begin(
            key=idempotency_key,
            user_id=user.id,
            endpoint="POST /marketplace/listings",
            request_payload=payload.model_dump(mode="json"),
        )
        if replay is not None:
            return ListingRead.model_validate(replay.body)

    listing = await listing_service.create_listing(
        seller_farmer_id=farmer.id,
        actor_user_id=user.id,
        listing_kind=payload.listing_kind.value,
        product_code=payload.product_code,
        product_name=payload.product_name,
        description=payload.description,
        field_id=payload.field_id,
        crop_cycle_id=payload.crop_cycle_id,
        quantity_total=payload.quantity_total,
        quantity_unit=payload.quantity_unit.value,
        asking_price_minor=payload.asking_price_minor,
        currency=payload.currency,
        grade=payload.grade,
        harvest_date=payload.harvest_date,
        available_from=payload.available_from,
        delivery_mode=payload.delivery_mode.value,
        country_code=payload.country_code,
        region=payload.region,
        district=payload.district,
        upazila=payload.upazila,
        attributes=payload.attributes,
        request_id=get_request_id(request),
    )

    # `farmer` was already loaded above - reuse its display_name instead
    # of a second round-trip query for the seller summary.
    response = _to_read_model(ListingWithSeller(listing=listing, seller_display_name=farmer.display_name))
    if guard is not None:
        await guard.finish(
            reservation, status_code=status.HTTP_201_CREATED, body=response.model_dump(mode="json")
        )
    return response


@router.get("/listings", response_model=CursorPage[ListingRead])
async def browse_listings(
    listing_service: ListingServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
    listing_kind: Annotated[ListingKind | None, Query()] = None,
    product_code: Annotated[str | None, Query()] = None,
    country_code: Annotated[str | None, Query()] = None,
    district: Annotated[str | None, Query()] = None,
    status_filter: Annotated[ListingStatus | None, Query(alias="status")] = None,
    min_price_minor: Annotated[int | None, Query(ge=0)] = None,
    max_price_minor: Annotated[int | None, Query(ge=0)] = None,
) -> CursorPage[ListingRead]:
    """Unauthenticated browse - defaults to ACTIVE listings only.
    `listing_kind`/`status` are real enums (Task 9): an unknown value is
    a 422, never a silently-empty page."""
    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    listings = await listing_service.list_active(
        limit=page_size + 1,
        cursor=decoded_cursor,
        listing_kind=listing_kind.value if listing_kind else None,
        product_code=product_code,
        country_code=country_code,
        district=district,
        status_filter=status_filter.value if status_filter else None,
        min_price_minor=min_price_minor,
        max_price_minor=max_price_minor,
    )

    has_more = len(listings) > page_size
    page = listings[:page_size]
    next_cursor = (
        encode_cursor(page[-1].listing.created_at, page[-1].listing.id) if has_more and page else None
    )

    return CursorPage[ListingRead](
        items=[_to_read_model(record) for record in page], next_cursor=next_cursor, has_more=has_more
    )


@router.get("/my-listings", response_model=CursorPage[ListingRead])
async def my_listings(
    user: CurrentUser,
    listing_service: ListingServiceDep,
    farmer_service: FarmerServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
) -> CursorPage[ListingRead]:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    listings = await listing_service.list_my_listings(
        seller_farmer_id=farmer.id, limit=page_size + 1, cursor=decoded_cursor
    )

    has_more = len(listings) > page_size
    page = listings[:page_size]
    next_cursor = (
        encode_cursor(page[-1].listing.created_at, page[-1].listing.id) if has_more and page else None
    )

    return CursorPage[ListingRead](
        items=[_to_read_model(record) for record in page], next_cursor=next_cursor, has_more=has_more
    )


@router.get("/listings/{listing_id}", response_model=ListingRead)
async def get_listing(listing_id: uuid.UUID, listing_service: ListingServiceDep) -> ListingRead:
    record = await listing_service.get_listing(listing_id)
    return _to_read_model(record)


@router.post("/listings/{listing_id}/close", response_model=ListingRead)
async def close_listing(
    listing_id: uuid.UUID,
    request: Request,
    user: CurrentUser,
    listing_service: ListingServiceDep,
    farmer_service: FarmerServiceDep,
) -> ListingRead:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)
    await listing_service.close_listing(
        listing_id=listing_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        request_id=get_request_id(request),
    )
    record = await listing_service.get_listing(listing_id)
    return _to_read_model(record)
