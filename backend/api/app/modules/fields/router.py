"""Field HTTP layer."""

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
from app.modules.admin.repository import AuditRepository, IdempotencyRepository, OutboxRepository
from app.modules.farmers.repository import FarmerRepository
from app.modules.farmers.service import FarmerService
from app.modules.fields.repository import FieldRecord, FieldRepository
from app.modules.fields.schemas import Centroid, FieldCreate, FieldRead, FieldUpdate
from app.modules.fields.service import FieldService, area_sq_m_to_acres

router = APIRouter(prefix="/fields", tags=["fields"])


def get_field_service(
    session: DbSession,
    outbox: Annotated[OutboxRepository, Depends(get_outbox_repository)],
    audit: Annotated[AuditRepository, Depends(get_audit_repository)],
) -> FieldService:
    return FieldService(FieldRepository(session), outbox, audit)


def get_farmer_service(session: DbSession) -> FarmerService:
    return FarmerService(FarmerRepository(session))


FieldServiceDep = Annotated[FieldService, Depends(get_field_service)]
FarmerServiceDep = Annotated[FarmerService, Depends(get_farmer_service)]


def _to_read_model(record: FieldRecord) -> FieldRead:
    field = record.field
    return FieldRead(
        id=field.id,
        farmer_id=field.farmer_id,
        name=field.name,
        boundary=record.boundary_geojson,
        centroid=Centroid(
            longitude=record.centroid_longitude,
            latitude=record.centroid_latitude,
        ),
        area_sq_m=field.area_sq_m,
        area_acres=round(area_sq_m_to_acres(field.area_sq_m), 4),
        country_code=field.country_code,
        region=field.region,
        district=field.district,
        upazila=field.upazila,
        status=field.status,
        created_at=field.created_at,
        updated_at=field.updated_at,
        version=field.version,
    )


@router.post("", response_model=FieldRead, status_code=status.HTTP_201_CREATED)
async def create_field(
    payload: FieldCreate,
    request: Request,
    user: CurrentUser,
    session: DbSession,
    field_service: FieldServiceDep,
    farmer_service: FarmerServiceDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> FieldRead:
    """Creates a field from a GeoJSON polygon.

    Safe to retry with an `Idempotency-Key` header: a replayed request
    returns the original field instead of creating a duplicate.
    """
    farmer = await farmer_service.ensure_profile_for_user(
        user_id=user.id, country_code=payload.country_code
    )

    guard: IdempotencyGuard | None = None
    reservation = None
    if idempotency_key:
        guard = IdempotencyGuard(IdempotencyRepository(session))
        replay, reservation = await guard.begin(
            key=idempotency_key,
            user_id=user.id,
            endpoint="POST /fields",
            request_payload=payload.model_dump(mode="json"),
        )
        if replay is not None:
            return FieldRead.model_validate(replay.body)

    record = await field_service.create_field(
        farmer_id=farmer.id,
        actor_user_id=user.id,
        name=payload.name,
        boundary_geojson=payload.boundary,
        country_code=payload.country_code,
        region=payload.region,
        district=payload.district,
        upazila=payload.upazila,
        request_id=get_request_id(request),
    )

    response = _to_read_model(record)
    if guard is not None:
        await guard.finish(
            reservation,
            status_code=status.HTTP_201_CREATED,
            body=response.model_dump(mode="json"),
        )
    return response


@router.get("", response_model=CursorPage[FieldRead])
async def list_fields(
    user: CurrentUser,
    field_service: FieldServiceDep,
    farmer_service: FarmerServiceDep,
    page_size: PageSize,
    cursor: Annotated[str | None, Query()] = None,
    include_archived: Annotated[bool, Query()] = False,
) -> CursorPage[FieldRead]:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    decoded_cursor = None
    if cursor:
        try:
            decoded_cursor = decode_cursor(cursor)
        except ValueError as exc:
            raise ValidationAppError(str(exc)) from exc

    # Fetch one extra row to detect whether another page exists.
    records = await field_service.list_fields(
        farmer_id=farmer.id,
        limit=page_size + 1,
        cursor=decoded_cursor,
        include_archived=include_archived,
    )

    has_more = len(records) > page_size
    page_records = records[:page_size]
    next_cursor = (
        encode_cursor(page_records[-1].field.created_at, page_records[-1].field.id)
        if has_more and page_records
        else None
    )

    return CursorPage[FieldRead](
        items=[_to_read_model(record) for record in page_records],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.get("/{field_id}", response_model=FieldRead)
async def get_field(
    field_id: uuid.UUID,
    user: CurrentUser,
    field_service: FieldServiceDep,
    farmer_service: FarmerServiceDep,
) -> FieldRead:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)
    record = await field_service.get_field(
        field_id=field_id, farmer_id=farmer.id, role_codes=user.role_codes
    )
    return _to_read_model(record)


@router.patch("/{field_id}", response_model=FieldRead)
async def update_field(
    field_id: uuid.UUID,
    payload: FieldUpdate,
    request: Request,
    user: CurrentUser,
    field_service: FieldServiceDep,
    farmer_service: FarmerServiceDep,
) -> FieldRead:
    farmer = await farmer_service.ensure_profile_for_user(user_id=user.id)

    changes = payload.model_dump(exclude={"expected_version"}, exclude_none=True)
    if "status" in changes:
        changes["status"] = str(changes["status"])

    record = await field_service.update_field(
        field_id=field_id,
        farmer_id=farmer.id,
        role_codes=user.role_codes,
        actor_user_id=user.id,
        changes=changes,
        expected_version=payload.expected_version,
        request_id=get_request_id(request),
    )
    return _to_read_model(record)
