"""Listing business logic."""

import uuid
from datetime import date, datetime
from decimal import Decimal

from app.modules.admin.repository import AuditRepository, OutboxRepository
from app.modules.crop_cycles.repository import CropCycleRepository
from app.modules.fields.repository import FieldRepository
from app.modules.marketplace import events, policies
from app.modules.marketplace.exceptions import (
    ListingAccessDeniedError,
    ListingAlreadyClosedError,
    ListingCropCycleFieldMismatchError,
    ListingCropCycleNotFoundError,
    ListingFieldNotFoundError,
    ListingNotFoundError,
)
from app.modules.marketplace.models import Listing
from app.modules.marketplace.repository import ListingRepository, ListingWithSeller
from app.shared.enums import ListingStatus

# A listing in any of these statuses can never accept a new bid or be
# closed again - see Task 19/20's explicit business rule.
_TERMINAL_STATUSES = {
    ListingStatus.SOLD_OUT.value,
    ListingStatus.CLOSED.value,
    ListingStatus.CANCELLED.value,
}


class ListingService:
    def __init__(
        self,
        repository: ListingRepository,
        outbox: OutboxRepository,
        audit: AuditRepository,
        field_repository: FieldRepository,
        crop_cycle_repository: CropCycleRepository,
    ) -> None:
        self._repository = repository
        self._outbox = outbox
        self._audit = audit
        self._fields = field_repository
        self._crop_cycles = crop_cycle_repository

    async def _verify_field_and_crop_cycle_ownership(
        self, *, seller_farmer_id: uuid.UUID, field_id: uuid.UUID | None, crop_cycle_id: uuid.UUID | None
    ) -> None:
        """Task 1/2: a farmer must never reference another farmer's field
        or crop cycle. A missing or foreign field/cycle id is reported as
        404, never revealing whether it belongs to someone else."""
        if field_id is not None:
            field_record = await self._fields.get_by_id(field_id)
            if field_record is None or field_record.field.farmer_id != seller_farmer_id:
                raise ListingFieldNotFoundError(f"Field {field_id} not found")

        if crop_cycle_id is not None:
            cycle = await self._crop_cycles.get_by_id(crop_cycle_id)
            if cycle is None:
                raise ListingCropCycleNotFoundError(f"Crop cycle {crop_cycle_id} not found")

            cycle_field = await self._fields.get_by_id(cycle.field_id)
            if cycle_field is None or cycle_field.field.farmer_id != seller_farmer_id:
                # The cycle exists but its field is not this seller's -
                # reported the same way as "cycle not found", per Task 1's
                # "404 rather than revealing another farmer's ... existence".
                raise ListingCropCycleNotFoundError(f"Crop cycle {crop_cycle_id} not found")

            if field_id is not None and cycle.field_id != field_id:
                raise ListingCropCycleFieldMismatchError(
                    "crop_cycle_id does not belong to the supplied field_id"
                )

    async def create_listing(
        self,
        *,
        seller_farmer_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        listing_kind: str,
        product_code: str | None,
        product_name: str,
        description: str | None,
        field_id: uuid.UUID | None,
        crop_cycle_id: uuid.UUID | None,
        quantity_total: Decimal,
        quantity_unit: str,
        asking_price_minor: int | None,
        currency: str,
        grade: str | None,
        harvest_date: date | None,
        available_from: date | None,
        delivery_mode: str,
        country_code: str,
        region: str | None,
        district: str | None,
        upazila: str | None,
        attributes: dict,
        request_id: str | None = None,
    ) -> Listing:
        await self._verify_field_and_crop_cycle_ownership(
            seller_farmer_id=seller_farmer_id, field_id=field_id, crop_cycle_id=crop_cycle_id
        )

        listing = await self._repository.create(
            seller_farmer_id=seller_farmer_id,
            listing_kind=listing_kind,
            product_code=product_code,
            product_name=product_name,
            description=description,
            field_id=field_id,
            crop_cycle_id=crop_cycle_id,
            quantity_total=quantity_total,
            quantity_unit=quantity_unit,
            asking_price_minor=asking_price_minor,
            currency=currency,
            grade=grade,
            harvest_date=harvest_date,
            available_from=available_from,
            delivery_mode=delivery_mode,
            country_code=country_code,
            region=region,
            district=district,
            upazila=upazila,
            attributes=attributes,
        )

        await self._outbox.append(
            events.listing_created(
                listing_id=listing.id,
                seller_farmer_id=seller_farmer_id,
                listing_kind=listing_kind,
                product_name=product_name,
                quantity_total=str(quantity_total),
                quantity_unit=quantity_unit,
                currency=currency,
            )
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.listing.create",
            entity_type="commerce.listings",
            entity_id=listing.id,
            context={"listing_kind": listing_kind, "product_name": product_name},
            request_id=request_id,
        )
        return listing

    async def get_listing(self, listing_id: uuid.UUID) -> ListingWithSeller:
        record = await self._repository.get_by_id_with_seller(listing_id)
        if record is None:
            raise ListingNotFoundError(f"Listing {listing_id} not found")
        return record

    async def list_active(
        self,
        *,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None,
        listing_kind: str | None,
        product_code: str | None,
        country_code: str | None,
        district: str | None,
        status_filter: str | None,
        min_price_minor: int | None,
        max_price_minor: int | None,
    ) -> list[ListingWithSeller]:
        return await self._repository.list_active(
            limit=limit,
            cursor=cursor,
            listing_kind=listing_kind,
            product_code=product_code,
            country_code=country_code,
            district=district,
            status_filter=status_filter,
            min_price_minor=min_price_minor,
            max_price_minor=max_price_minor,
        )

    async def list_my_listings(
        self,
        *,
        seller_farmer_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None,
    ) -> list[ListingWithSeller]:
        return await self._repository.list_by_seller(
            seller_farmer_id=seller_farmer_id, limit=limit, cursor=cursor
        )

    async def close_listing(
        self,
        *,
        listing_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        request_id: str | None = None,
    ) -> Listing:
        listing = await self._repository.get_by_id(listing_id)
        if listing is None:
            raise ListingNotFoundError(f"Listing {listing_id} not found")

        if not policies.can_write_listing(listing=listing, farmer_id=farmer_id, role_codes=role_codes):
            raise ListingAccessDeniedError("You cannot close this listing")

        if listing.status in _TERMINAL_STATUSES:
            raise ListingAlreadyClosedError(
                f"Listing is already {listing.status} and cannot be closed again"
            )

        updated = await self._repository.close(listing_id)
        if updated is None:  # pragma: no cover - raced with itself between the two reads
            raise ListingAlreadyClosedError("Listing was closed by a concurrent request")

        await self._outbox.append(events.listing_closed(listing_id=listing_id, reason="seller_closed"))
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="marketplace.listing.close",
            entity_type="commerce.listings",
            entity_id=listing_id,
            context={"previous_status": listing.status},
            request_id=request_id,
        )
        return updated
