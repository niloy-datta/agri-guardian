"""Database access for listings."""

import uuid
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Select, and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.farmers.models import FarmerProfile
from app.modules.marketplace.models import Listing
from app.shared.enums import ListingStatus


@dataclass(slots=True)
class ListingWithSeller:
    """A listing plus its seller's safe display name - joined in one
    query (Task 3) so the mobile client never has to make a second
    request per listing to show who is selling."""

    listing: Listing
    seller_display_name: str | None


class ListingRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        seller_farmer_id: uuid.UUID,
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
    ) -> Listing:
        listing = Listing(
            seller_farmer_id=seller_farmer_id,
            listing_kind=listing_kind,
            product_code=product_code,
            product_name=product_name,
            description=description,
            field_id=field_id,
            crop_cycle_id=crop_cycle_id,
            quantity_total=quantity_total,
            quantity_available=quantity_total,
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
            status=ListingStatus.ACTIVE.value,
        )
        self._session.add(listing)
        await self._session.flush()
        return listing

    async def get_by_id(self, listing_id: uuid.UUID) -> Listing | None:
        stmt = select(Listing).where(Listing.id == listing_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_for_update(self, listing_id: uuid.UUID) -> Listing | None:
        """Locks the row for the duration of the caller's transaction -
        the first lock taken in the bid-acceptance path (Task 26: listing
        before bid), so two concurrent acceptances against the same
        listing serialize instead of both reading a stale
        `quantity_available`."""
        stmt = select(Listing).where(Listing.id == listing_id).with_for_update()
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_with_seller(self, listing_id: uuid.UUID) -> ListingWithSeller | None:
        stmt = self._select_with_seller().where(Listing.id == listing_id)
        result = await self._session.execute(stmt)
        row = result.first()
        return self._to_record(row) if row else None

    def _base_query(self) -> Select:
        return select(Listing)

    def _select_with_seller(self) -> Select:
        return select(Listing, FarmerProfile.display_name).outerjoin(
            FarmerProfile, FarmerProfile.id == Listing.seller_farmer_id
        )

    @staticmethod
    def _to_record(row) -> ListingWithSeller:
        return ListingWithSeller(listing=row[0], seller_display_name=row[1])

    async def list_active(
        self,
        *,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
        listing_kind: str | None = None,
        product_code: str | None = None,
        country_code: str | None = None,
        district: str | None = None,
        status_filter: str | None = None,
        min_price_minor: int | None = None,
        max_price_minor: int | None = None,
    ) -> list[ListingWithSeller]:
        stmt = self._select_with_seller()
        stmt = stmt.where(Listing.status == (status_filter or ListingStatus.ACTIVE.value))

        if listing_kind is not None:
            stmt = stmt.where(Listing.listing_kind == listing_kind)
        if product_code is not None:
            stmt = stmt.where(Listing.product_code == product_code)
        if country_code is not None:
            stmt = stmt.where(Listing.country_code == country_code)
        if district is not None:
            stmt = stmt.where(Listing.district == district)
        if min_price_minor is not None:
            stmt = stmt.where(Listing.asking_price_minor >= min_price_minor)
        if max_price_minor is not None:
            stmt = stmt.where(Listing.asking_price_minor <= max_price_minor)

        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    Listing.created_at < cursor_created_at,
                    and_(Listing.created_at == cursor_created_at, Listing.id < cursor_id),
                )
            )

        stmt = stmt.order_by(Listing.created_at.desc(), Listing.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def list_by_seller(
        self,
        *,
        seller_farmer_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
    ) -> list[ListingWithSeller]:
        stmt = self._select_with_seller().where(Listing.seller_farmer_id == seller_farmer_id)

        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    Listing.created_at < cursor_created_at,
                    and_(Listing.created_at == cursor_created_at, Listing.id < cursor_id),
                )
            )

        stmt = stmt.order_by(Listing.created_at.desc(), Listing.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def close(self, listing_id: uuid.UUID) -> Listing | None:
        stmt = (
            update(Listing)
            .where(Listing.id == listing_id)
            .values(status=ListingStatus.CLOSED.value, version=Listing.version + 1)
            .returning(Listing.id)
        )
        result = await self._session.execute(stmt)
        if result.scalar_one_or_none() is None:
            return None
        return await self.get_by_id(listing_id)

    async def decrement_available(
        self, *, listing_id: uuid.UUID, quantity: Decimal, new_status: str | None
    ) -> None:
        """Applies the inventory decrement. Caller must already hold the
        row lock from `get_for_update` and must have already verified
        `quantity_available >= quantity` - this method trusts that check
        rather than repeating it, since it always runs inside the same
        locked transaction."""
        values: dict[str, object] = {
            "quantity_available": Listing.quantity_available - quantity,
            "version": Listing.version + 1,
        }
        if new_status is not None:
            values["status"] = new_status
        await self._session.execute(update(Listing).where(Listing.id == listing_id).values(**values))
