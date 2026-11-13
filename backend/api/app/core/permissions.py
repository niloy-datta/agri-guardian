"""Role-based authorization dependencies.

Each domain module's `policies.py` should build on `require_roles` rather
than re-implementing role checks, keeping authorization rules declarative
and testable independent of `service.py` business logic.
"""

from collections.abc import Callable

from fastapi import Depends, HTTPException, status

from app.core.dependencies import get_current_user
from app.modules.identity.models import User


def require_roles(*allowed_roles: str) -> Callable:
    """Returns a FastAPI dependency that authorizes only users holding at
    least one of `allowed_roles`."""

    async def _dependency(user: User = Depends(get_current_user)) -> User:
        if not user.role_codes.intersection(allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires one of roles: {sorted(allowed_roles)}",
            )
        return user

    return _dependency
