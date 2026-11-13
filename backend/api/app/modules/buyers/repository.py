"""Database access for buyer profiles."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.buyers.models import BuyerProfile


class BuyerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_user_id(self, user_id: uuid.UUID) -> BuyerProfile | None:
        stmt = select(BuyerProfile).where(BuyerProfile.user_id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id(self, buyer_id: uuid.UUID) -> BuyerProfile | None:
        stmt = select(BuyerProfile).where(BuyerProfile.id == buyer_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        display_name: str | None = None,
        business_name: str | None = None,
        country_code: str | None = None,
        region: str | None = None,
        district: str | None = None,
    ) -> BuyerProfile:
        profile = BuyerProfile(
            user_id=user_id,
            display_name=display_name,
            business_name=business_name,
            country_code=country_code.upper() if country_code else None,
            region=region,
            district=district,
        )
        self._session.add(profile)
        await self._session.flush()
        return profile
