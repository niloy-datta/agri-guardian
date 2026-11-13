"""Farmer profile business logic."""

import uuid

from app.modules.farmers.models import FarmerProfile
from app.modules.farmers.repository import FarmerRepository

DEFAULT_COUNTRY_CODE = "BD"


class FarmerService:
    def __init__(self, repository: FarmerRepository) -> None:
        self._repository = repository

    async def ensure_profile_for_user(
        self,
        *,
        user_id: uuid.UUID,
        country_code: str | None = None,
        display_name: str | None = None,
    ) -> FarmerProfile:
        """Returns the caller's farmer profile, creating it on first use.

        Bangladesh is only the default country pack, not an assumption:
        `country_code` is a real column and any ISO code is accepted.
        """
        existing = await self._repository.get_by_user_id(user_id)
        if existing is not None:
            return existing

        return await self._repository.create(
            user_id=user_id,
            country_code=(country_code or DEFAULT_COUNTRY_CODE),
            display_name=display_name,
        )

    async def get_by_id(self, farmer_id: uuid.UUID) -> FarmerProfile | None:
        return await self._repository.get_by_id(farmer_id)
