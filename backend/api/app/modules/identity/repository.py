"""Database access for the identity module. No business rules live here."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.identity.models import Profile, Role, User, UserRole


class IdentityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_user_by_auth_subject(self, auth_subject: str) -> User | None:
        stmt = select(User).where(User.auth_subject == auth_subject)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_user_by_id(self, user_id: uuid.UUID) -> User | None:
        stmt = select(User).where(User.id == user_id)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create_user(
        self,
        *,
        auth_subject: str,
        email: str | None,
        phone: str | None,
        country_code: str | None = None,
    ) -> User:
        user = User(
            auth_subject=auth_subject,
            email=email,
            phone=phone,
            country_code=country_code,
        )
        self._session.add(user)
        await self._session.flush()
        return user

    async def create_profile(self, *, user_id: uuid.UUID) -> Profile:
        profile = Profile(user_id=user_id)
        self._session.add(profile)
        await self._session.flush()
        return profile

    async def get_role_by_code(self, code: str) -> Role | None:
        stmt = select(Role).where(Role.code == code)
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_roles(self) -> list[Role]:
        result = await self._session.execute(select(Role).order_by(Role.code))
        return list(result.scalars().all())

    async def assign_role(self, *, user_id: uuid.UUID, role_id: uuid.UUID) -> UserRole:
        user_role = UserRole(user_id=user_id, role_id=role_id)
        self._session.add(user_role)
        await self._session.flush()
        return user_role

    async def has_role(self, *, user_id: uuid.UUID, role_id: uuid.UUID) -> bool:
        stmt = select(UserRole.id).where(
            UserRole.user_id == user_id, UserRole.role_id == role_id
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def refresh_user(self, user: User) -> User:
        await self._session.refresh(user, ["user_roles", "profile"])
        return user
