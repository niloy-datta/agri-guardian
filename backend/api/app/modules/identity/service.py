"""Identity business logic.

The auth provider owns credentials. This service's job is to keep a local
`identity.users` row in sync with the verified token so every other domain
has a stable foreign key, and to manage role assignment.
"""

import uuid

from app.core.security import TokenClaims
from app.modules.admin.repository import OutboxRepository
from app.modules.identity import events
from app.modules.identity.exceptions import (
    RoleAlreadyAssignedError,
    RoleNotFoundError,
    UserNotFoundError,
)
from app.modules.identity.models import Role, User
from app.modules.identity.repository import IdentityRepository
from app.shared.enums import RoleCode


class IdentityService:
    def __init__(
        self,
        repository: IdentityRepository,
        outbox: OutboxRepository | None = None,
    ) -> None:
        self._repository = repository
        self._outbox = outbox

    async def sync_user_from_claims(self, claims: TokenClaims) -> User:
        """Returns the local user for a verified token, creating it on first sight.

        First-sight provisioning keeps the client from needing a separate
        registration round-trip after signup, and emits `UserRegistered` so
        downstream domains can react.
        """
        user = await self._repository.get_user_by_auth_subject(claims.user_id)
        if user is not None:
            return user

        user = await self._repository.create_user(
            auth_subject=claims.user_id,
            email=claims.email,
            phone=claims.phone,
        )
        await self._repository.create_profile(user_id=user.id)

        if self._outbox is not None:
            await self._outbox.append(
                events.user_registered(
                    user_id=user.id,
                    auth_subject=claims.user_id,
                    email=claims.email,
                )
            )

        await self._repository.refresh_user(user)
        return user

    async def get_user(self, user_id: uuid.UUID) -> User:
        user = await self._repository.get_user_by_id(user_id)
        if user is None:
            raise UserNotFoundError(f"User {user_id} not found")
        return user

    async def assign_role(self, *, user_id: uuid.UUID, role_code: RoleCode | str) -> Role:
        code = str(role_code)
        role = await self._repository.get_role_by_code(code)
        if role is None:
            raise RoleNotFoundError(f"Role {code} is not defined")

        if await self._repository.has_role(user_id=user_id, role_id=role.id):
            raise RoleAlreadyAssignedError(f"User already holds role {code}")

        await self._repository.assign_role(user_id=user_id, role_id=role.id)
        return role

    async def list_roles(self) -> list[Role]:
        return await self._repository.list_roles()
