"""Crop cycle HTTP layer.

Two routers, because a cycle has two natural addresses: nested under the
field that owns it (create/list, where the field is the collection) and by
its own id (read/update). All ownership, concurrency and one-active-cycle
rules live in `service.py`; this layer only translates HTTP.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request, status

from app.core.dependencies import (
    CurrentUser,
    DbSession,
    PageSize,
    get_audit_repository,
    get_outbox_repository,
    get_request_id,
)
from app.core.exceptions import ValidationAppError
from app.core.idempotency import IdempotencyGuard, IdempotencyKeyHeader
from app.core.pagination import CursorPage, decode_cursor, encode_cursor
from app.modules.admin.repository import (
    AuditRepository,
    IdempotencyRepository,
    OutboxRepository,
)
from app.modules.crop_cycles.repository import CropCycleRepository
from app.modules.crop_cycles.schemas import (
    CropCycleCreate,
    CropCycleRead,
    CropCycleUpdate,
)
from app.modules.crop_cycles.service import CropCycleService
from app.modules.farmers.repository import FarmerRepository
from app.modules.farmers.service import FarmerService
from app.modules.fields.repository import FieldRepository

field_crop_cycles_router = APIRouter(
    prefix="/fields/{field_id}/crop-cycles", tags=["crop-cycles"]
)
router = APIRouter(prefix="/crop-cycles", tags=["crop-cycles"])


def get_crop_cycle_service(
    session: DbSession,
    outbox: Annotated[OutboxRepository, Depends(get_outbox_repository)],
    audit: Annotated[AuditRepository, Depends(get_audit_repository)],
) -> CropCycleService:
    return CropCycleService(
        CropCycleRepository(session), FieldRepository(session), outbox, audit
    )


def get_farmer_service(session: DbSession) -> FarmerService:
    return FarmerService(FarmerRepository(session))


CropCycleServiceDep = Annotated[CropCycleService, Depends(get_crop_cycle_service)]
FarmerServiceDep = Annotated[FarmerService, Depends(get_farmer_service)]


@field_crop_cycles_router.post(
    "", response_model=CropCycleRead, status_code=status.HTTP_201_CREATED
)
async def create_crop_cycle(
    field_id: uuid.UUID,
    payload: CropCycleCreate,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    cycle_service: CropCycleServiceDep,
    farmer_service: FarmerServiceDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> CropCycleRead:
    """Starts a crop cycle on a field the caller may write to.

    Safe to retry with an `Idempotency-Key` header, matching the field
    create endpoint: the Flutter client replays queued offline mutations.
    """
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    guard: IdempotencyGuard | None = None
    reservation = None
    if idempotency_key:
        guard = IdempotencyGuard(IdempotencyRepository(session))
        replay, reservation = await guard.begin(
            key=idempotency_key,
            user_id=user.id,
            endpoint=f"POST /fields/{field_id}/crop-cycles",
            request_payload=payload.model_dump(mode="json"),
        )
        if replay is not None:
            return CropCycleRead.model_validate(replay.body)

    cycle = await cycle_service.create_cycle(
        field_id=field_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        crop_code=payload.crop_code,
        variety=payload.variety,
        planting_date=payload.planting_date,
        expected_harvest_date=payload.expected_harvest_date,
        current_stage=payload.current_stage,
        irrigation_type=(
            str(payload.irrigation_type) if payload.irrigation_type else None
        ),
        status=str(payload.status),
        request_id=get_request_id(request),
    )

    response = CropCycleRead.model_validate(cycle)
    if guard is not None:
        await guard.finish(
            reservation,
            status_code=status.HTTP_201_CREATED,
            body=response.model_dump(mode="json"),
        )
    return response


@field_crop_cycles_router.get("", response_model=CursorPage[CropCycleRead])
async def list_crop_cycles(
    field_id: uuid.UUID,
    user: CurrentUser,
    cycle_service: CropCycleServiceDep,
    farmer_service: FarmerServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
) -> CursorPage[CropCycleRead]:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    # One extra row tells us whether another page exists without a count().
    cycles = await cycle_service.list_cycles_for_field(
        field_id=field_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        limit=page_size + 1,
        cursor=decoded_cursor,
    )

    has_more = len(cycles) > page_size
    page = cycles[:page_size]
    next_cursor = (
        encode_cursor(page[-1].created_at, page[-1].id) if has_more and page else None
    )

    return CursorPage[CropCycleRead](
        items=[CropCycleRead.model_validate(cycle) for cycle in page],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.get("/{cycle_id}", response_model=CropCycleRead)
async def get_crop_cycle(
    cycle_id: uuid.UUID,
    user: CurrentUser,
    cycle_service: CropCycleServiceDep,
    farmer_service: FarmerServiceDep,
) -> CropCycleRead:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)
    cycle = await cycle_service.get_cycle(
        cycle_id=cycle_id, farmer_id=farmer.id, role_codes=user.role_codes
    )
    return CropCycleRead.model_validate(cycle)


@router.patch("/{cycle_id}", response_model=CropCycleRead)
async def update_crop_cycle(
    cycle_id: uuid.UUID,
    payload: CropCycleUpdate,
    request: Request,
    user: CurrentUser,
    cycle_service: CropCycleServiceDep,
    farmer_service: FarmerServiceDep,
) -> CropCycleRead:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    changes = payload.model_dump(exclude={"expected_version"}, exclude_none=True)
    # StrEnum members must reach the repository as plain strings so the
    # CHECK constraints compare against the stored representation.
    for enum_field in ("status", "irrigation_type"):
        if enum_field in changes:
            changes[enum_field] = str(changes[enum_field])

    cycle = await cycle_service.update_cycle(
        cycle_id=cycle_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        changes=changes,
        expected_version=payload.expected_version,
        request_id=get_request_id(request),
    )
    return CropCycleRead.model_validate(cycle)
