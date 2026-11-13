"""Identity HTTP layer. No SQL, no business rules - delegates to the service."""

from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.dependencies import CurrentUser, get_identity_service
from app.modules.identity.models import User
from app.modules.identity.schemas import ProfileRead, UserRead
from app.modules.identity.service import IdentityService

router = APIRouter(prefix="/identity", tags=["identity"])


def _to_user_read(user: User) -> UserRead:
    return UserRead(
        id=user.id,
        email=user.email,
        phone=user.phone,
        country_code=user.country_code,
        status=user.status,
        roles=sorted(user.role_codes),
        profile=ProfileRead.model_validate(user.profile) if user.profile else None,
        created_at=user.created_at,
        updated_at=user.updated_at,
        version=user.version,
    )


@router.get("/me", response_model=UserRead, status_code=status.HTTP_200_OK)
async def read_me(user: CurrentUser) -> UserRead:
    """Returns the caller, provisioning the local mirror on first sight."""
    return _to_user_read(user)


@router.get("/roles", response_model=list[str])
async def list_roles(
    _: CurrentUser,
    identity_service: Annotated[IdentityService, Depends(get_identity_service)],
) -> list[str]:
    roles = await identity_service.list_roles()
    return [role.code for role in roles]
