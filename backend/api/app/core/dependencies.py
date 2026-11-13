"""Shared FastAPI dependencies.

This module is the composition root: it wires verified token claims to a
local user, and repositories to sessions. Domain `service.py` files stay
free of FastAPI imports so they can be reused by workers and tests.
"""

from typing import Annotated

from fastapi import Depends, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.pagination import clamp_page_size
from app.core.security import TokenClaims, get_current_claims
from app.modules.admin.repository import AuditRepository, OutboxRepository
from app.modules.identity.models import User
from app.modules.identity.repository import IdentityRepository
from app.modules.identity.service import IdentityService

DbSession = Annotated[AsyncSession, Depends(get_db)]


def get_outbox_repository(session: DbSession) -> OutboxRepository:
    return OutboxRepository(session)


def get_audit_repository(session: DbSession) -> AuditRepository:
    return AuditRepository(session)


def get_identity_service(
    session: DbSession,
    outbox: Annotated[OutboxRepository, Depends(get_outbox_repository)],
) -> IdentityService:
    return IdentityService(IdentityRepository(session), outbox)


async def get_current_user(
    claims: Annotated[TokenClaims, Depends(get_current_claims)],
    identity_service: Annotated[IdentityService, Depends(get_identity_service)],
) -> User:
    """Verified caller, provisioned locally on first sight."""
    return await identity_service.sync_user_from_claims(claims)


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_request_id(request: Request) -> str | None:
    return request.headers.get("X-Request-ID")


def get_page_size(
    limit: Annotated[int | None, Query(ge=1, le=100)] = None,
) -> int:
    return clamp_page_size(limit)


PageSize = Annotated[int, Depends(get_page_size)]
