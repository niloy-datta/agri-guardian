"""Database access for bids."""

import base64
import binascii
import json
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.bidding.models import Bid
from app.modules.buyers.models import BuyerProfile
from app.modules.marketplace.models import Listing
from app.shared.enums import BidStatus


@dataclass(slots=True)
class BidWithContext:
    """A bid plus the safe buyer-display and listing-summary context the
    mobile client needs (Task 4/5) - joined in one query so neither the
    seller bid inbox nor `my-bids` ever has to make a second request per
    row."""

    bid: Bid
    buyer_display_name: str | None
    listing_product_name: str
    listing_kind: str
    listing_quantity_unit: str
    listing_district: str | None
    listing_status: str


def encode_price_cursor(unit_price_minor: int, created_at: datetime, row_id: uuid.UUID) -> str:
    """Cursor for the `sort=price_desc` bid-inbox ordering (Task 8).

    A `(created_at, id)`-only cursor is wrong once results are ordered by
    price first: two bids with the same price but different creation
    times would otherwise be able to skip or repeat across pages. This
    mirrors `app.core.pagination`'s cursor format exactly, but encodes
    the extra leading `unit_price_minor` field - `core/pagination.py` is
    not in this phase's allowed-to-touch list, so this is kept local to
    the one ordering that actually needs it.
    """
    payload = json.dumps([unit_price_minor, created_at.isoformat(), str(row_id)]).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii")


def decode_price_cursor(cursor: str) -> tuple[int, datetime, uuid.UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii"))
        price_str, created_at_str, row_id_str = json.loads(raw)
        return int(price_str), datetime.fromisoformat(created_at_str), uuid.UUID(row_id_str)
    except (ValueError, binascii.Error, json.JSONDecodeError, TypeError) as exc:
        raise ValueError("Invalid pagination cursor") from exc


class BidRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        listing_id: uuid.UUID,
        buyer_id: uuid.UUID,
        quantity: Decimal,
        unit_price_minor: int,
        currency: str,
        note: str | None,
        expires_at: datetime | None,
    ) -> Bid:
        bid = Bid(
            listing_id=listing_id,
            buyer_id=buyer_id,
            quantity=quantity,
            unit_price_minor=unit_price_minor,
            currency=currency,
            note=note,
            expires_at=expires_at,
            status=BidStatus.ACTIVE.value,
        )
        self._session.add(bid)
        await self._session.flush()
        return bid

    async def get_by_id(self, bid_id: uuid.UUID) -> Bid | None:
        stmt = select(Bid).where(Bid.id == bid_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_for_update(self, bid_id: uuid.UUID) -> Bid | None:
        """Locks the row - the second lock taken in the bid-acceptance
        path (Task 26: listing first, bid second), so the stable lock
        order never deadlocks against another acceptance attempt on a
        different bid for the same listing."""
        stmt = select(Bid).where(Bid.id == bid_id).with_for_update()
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    def _select_with_context(self):
        return (
            select(
                Bid,
                BuyerProfile.display_name,
                Listing.product_name,
                Listing.listing_kind,
                Listing.quantity_unit,
                Listing.district,
                Listing.status,
            )
            .join(Listing, Listing.id == Bid.listing_id)
            .outerjoin(BuyerProfile, BuyerProfile.id == Bid.buyer_id)
        )

    @staticmethod
    def _to_record(row) -> BidWithContext:
        return BidWithContext(
            bid=row[0],
            buyer_display_name=row[1],
            listing_product_name=row[2],
            listing_kind=row[3],
            listing_quantity_unit=row[4],
            listing_district=row[5],
            listing_status=row[6],
        )

    async def list_by_listing(
        self,
        *,
        listing_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
        price_cursor: tuple[int, datetime, uuid.UUID] | None = None,
        order_by_price_desc: bool = False,
    ) -> list[BidWithContext]:
        stmt = self._select_with_context().where(Bid.listing_id == listing_id)

        if order_by_price_desc:
            if price_cursor is not None:
                cursor_price, cursor_created_at, cursor_id = price_cursor
                stmt = stmt.where(
                    or_(
                        Bid.unit_price_minor < cursor_price,
                        and_(
                            Bid.unit_price_minor == cursor_price,
                            Bid.created_at < cursor_created_at,
                        ),
                        and_(
                            Bid.unit_price_minor == cursor_price,
                            Bid.created_at == cursor_created_at,
                            Bid.id < cursor_id,
                        ),
                    )
                )
            stmt = stmt.order_by(Bid.unit_price_minor.desc(), Bid.created_at.desc(), Bid.id.desc())
        else:
            if cursor is not None:
                cursor_created_at, cursor_id = cursor
                stmt = stmt.where(
                    or_(
                        Bid.created_at < cursor_created_at,
                        and_(Bid.created_at == cursor_created_at, Bid.id < cursor_id),
                    )
                )
            stmt = stmt.order_by(Bid.created_at.desc(), Bid.id.desc())

        stmt = stmt.limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def list_by_buyer(
        self,
        *,
        buyer_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
    ) -> list[BidWithContext]:
        stmt = self._select_with_context().where(Bid.buyer_id == buyer_id)

        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    Bid.created_at < cursor_created_at,
                    and_(Bid.created_at == cursor_created_at, Bid.id < cursor_id),
                )
            )

        stmt = stmt.order_by(Bid.created_at.desc(), Bid.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def withdraw(self, *, bid_id: uuid.UUID) -> Bid | None:
        stmt = (
            update(Bid)
            .where(Bid.id == bid_id, Bid.status == BidStatus.ACTIVE.value)
            .values(status=BidStatus.WITHDRAWN.value, version=Bid.version + 1)
            .returning(Bid.id)
        )
        result = await self._session.execute(stmt)
        if result.scalar_one_or_none() is None:
            return None
        return await self.get_by_id(bid_id)

    async def mark_accepted(self, *, bid_id: uuid.UUID) -> None:
        """Caller must already hold the row lock from `get_for_update` and
        have already verified `status == ACTIVE` - this trusts that check
        rather than repeating it inside the same locked transaction."""
        await self._session.execute(
            update(Bid)
            .where(Bid.id == bid_id)
            .values(status=BidStatus.ACCEPTED.value, version=Bid.version + 1)
        )

    async def reject_other_active_bids(
        self, *, listing_id: uuid.UUID, except_bid_id: uuid.UUID
    ) -> list[uuid.UUID]:
        """Bulk-rejects every other ACTIVE bid on a listing that has just
        gone SOLD_OUT (Task 29) - never deletes them, and never touches
        bids in any other status."""
        stmt = (
            update(Bid)
            .where(
                Bid.listing_id == listing_id,
                Bid.id != except_bid_id,
                Bid.status == BidStatus.ACTIVE.value,
            )
            .values(status=BidStatus.REJECTED.value, version=Bid.version + 1)
            .returning(Bid.id)
        )
        result = await self._session.execute(stmt)
        return list(result.scalars().all())
