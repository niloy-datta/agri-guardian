"""Database access for farmer profiles."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.farmers.models import FarmerProfile


class FarmerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_user_id(self, user_id: uuid.UUID) -> FarmerProfile | None:
        stmt = select(FarmerProfile).where(FarmerProfile.user_id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id(self, farmer_id: uuid.UUID) -> FarmerProfile | None:
        stmt = select(FarmerProfile).where(FarmerProfile.id == farmer_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        user_id: uuid.UUID,
        country_code: str,
        display_name: str | None = None,
        region: str | None = None,
        district: str | None = None,
        upazila: str | None = None,
    ) -> FarmerProfile:
        profile = FarmerProfile(
            user_id=user_id,
            country_code=country_code.upper(),
            display_name=display_name,
            region=region,
            district=district,
            upazila=upazila,
        )
        self._session.add(profile)
        await self._session.flush()
        return profile
