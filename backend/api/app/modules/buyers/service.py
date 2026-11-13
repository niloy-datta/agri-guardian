"""Buyer profile business logic.

Mirrors `FarmerService.ensure_profile_for_user` exactly: no admin approval
gate for MVP, and identity roles are never modified here - a user simply
gets a buyer profile the first time they act as a buyer (placing a bid).
"""

import uuid

from app.modules.buyers.models import BuyerProfile
from app.modules.buyers.repository import BuyerRepository


class BuyerService:
    def __init__(self, repository: BuyerRepository) -> None:
        self._repository = repository

    async def ensure_profile_for_user(
        self,
        *,
        user_id: uuid.UUID,
        country_code: str | None = None,
        display_name: str | None = None,
    ) -> BuyerProfile:
        existing = await self._repository.get_by_user_id(user_id)
        if existing is not None:
            return existing

        return await self._repository.create(
            user_id=user_id,
            display_name=display_name,
            country_code=country_code,
        )

    async def get_by_id(self, buyer_id: uuid.UUID) -> BuyerProfile | None:
        return await self._repository.get_by_id(buyer_id)
