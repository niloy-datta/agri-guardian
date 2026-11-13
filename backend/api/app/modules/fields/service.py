"""Field business logic.

Everything that decides *whether* and *what* happens lives here: geometry
validation, ownership, optimistic concurrency, audit trail and the outbox
append. The router only translates HTTP to these calls.
"""

import uuid
from datetime import datetime
from decimal import Decimal

from app.modules.admin.repository import AuditRepository, OutboxRepository
from app.modules.fields import events, policies
from app.modules.fields.exceptions import (
    FieldAccessDeniedError,
    FieldNotFoundError,
    FieldVersionConflictError,
    InvalidFieldBoundaryError,
)
from app.modules.fields.repository import FieldRecord, FieldRepository
from app.shared.enums import FieldStatus

SQ_M_PER_ACRE = Decimal("4046.8564224")


def area_sq_m_to_acres(area_sq_m: Decimal) -> float:
    return float(area_sq_m / SQ_M_PER_ACRE)


class FieldService:
    def __init__(
        self,
        repository: FieldRepository,
        outbox: OutboxRepository,
        audit: AuditRepository,
    ) -> None:
        self._repository = repository
        self._outbox = outbox
        self._audit = audit

    async def create_field(
        self,
        *,
        farmer_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        name: str,
        boundary_geojson: dict,
        country_code: str,
        region: str | None = None,
        district: str | None = None,
        upazila: str | None = None,
        request_id: str | None = None,
    ) -> FieldRecord:
        is_valid, reason = await self._repository.check_geometry_validity(boundary_geojson)
        if not is_valid:
            raise InvalidFieldBoundaryError(f"Invalid polygon geometry: {reason}")

        record = await self._repository.create(
            farmer_id=farmer_id,
            name=name,
            boundary_geojson=boundary_geojson,
            country_code=country_code,
            region=region,
            district=district,
            upazila=upazila,
        )

        await self._outbox.append(
            events.field_created(
                field_id=record.field.id,
                farmer_id=farmer_id,
                country_code=country_code,
                area_sq_m=float(record.field.area_sq_m),
                centroid_longitude=record.centroid_longitude,
                centroid_latitude=record.centroid_latitude,
            )
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="field.create",
            entity_type="farm.fields",
            entity_id=record.field.id,
            context={"name": name, "country_code": country_code},
            request_id=request_id,
        )
        return record

    async def get_field(
        self,
        *,
        field_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
    ) -> FieldRecord:
        record = await self._repository.get_by_id(field_id)
        if record is None:
            raise FieldNotFoundError(f"Field {field_id} not found")

        if not policies.can_read_field(
            field=record.field, farmer_id=farmer_id, role_codes=role_codes
        ):
            # 404 rather than 403 so ids of other farmers' fields are not probeable.
            raise FieldNotFoundError(f"Field {field_id} not found")

        return record

    async def list_fields(
        self,
        *,
        farmer_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
        include_archived: bool = False,
    ) -> list[FieldRecord]:
        return await self._repository.list_by_farmer(
            farmer_id=farmer_id,
            limit=limit,
            cursor=cursor,
            include_archived=include_archived,
        )

    async def update_field(
        self,
        *,
        field_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        changes: dict,
        expected_version: int | None = None,
        request_id: str | None = None,
    ) -> FieldRecord:
        current = await self._repository.get_by_id(field_id)
        if current is None:
            raise FieldNotFoundError(f"Field {field_id} not found")

        if not policies.can_write_field(
            field=current.field, farmer_id=farmer_id, role_codes=role_codes
        ):
            raise FieldAccessDeniedError("You cannot modify this field")

        applied = {key: value for key, value in changes.items() if value is not None}
        if not applied:
            return current

        updated = await self._repository.update_attributes(
            field_id=field_id, values=applied, expected_version=expected_version
        )
        if updated is None:
            raise FieldVersionConflictError(
                "Field was modified by someone else; refresh and retry"
            )

        await self._outbox.append(
            events.field_updated(field_id=field_id, changed_fields=sorted(applied))
        )
        if applied.get("status") == FieldStatus.ARCHIVED.value:
            await self._outbox.append(events.field_archived(field_id=field_id))

        await self._audit.record(
            actor_user_id=actor_user_id,
            action="field.update",
            entity_type="farm.fields",
            entity_id=field_id,
            context={"changed_fields": sorted(applied)},
            request_id=request_id,
        )
        return updated
