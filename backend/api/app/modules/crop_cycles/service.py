"""Crop cycle business logic."""

import uuid
from datetime import datetime

from app.modules.admin.repository import AuditRepository, OutboxRepository
from app.modules.crop_cycles import events, policies
from app.modules.crop_cycles.exceptions import (
    ActiveCropCycleExistsError,
    CropCycleNotFoundError,
    CropCycleVersionConflictError,
)
from app.modules.crop_cycles.models import CropCycle
from app.modules.crop_cycles.repository import CropCycleRepository
from app.modules.fields.exceptions import FieldAccessDeniedError, FieldNotFoundError
from app.modules.fields.repository import FieldRepository
from app.shared.enums import CropCycleStatus


class CropCycleService:
    def __init__(
        self,
        repository: CropCycleRepository,
        field_repository: FieldRepository,
        outbox: OutboxRepository,
        audit: AuditRepository,
    ) -> None:
        self._repository = repository
        self._field_repository = field_repository
        self._outbox = outbox
        self._audit = audit

    async def _authorized_field(
        self, *, field_id: uuid.UUID, farmer_id: uuid.UUID, role_codes: set[str], write: bool
    ):
        record = await self._field_repository.get_by_id(field_id)
        if record is None:
            raise FieldNotFoundError(f"Field {field_id} not found")

        allowed = (
            policies.can_write_cycle(
                field=record.field, farmer_id=farmer_id, role_codes=role_codes
            )
            if write
            else policies.can_read_cycle(
                field=record.field, farmer_id=farmer_id, role_codes=role_codes
            )
        )
        if not allowed:
            if write:
                raise FieldAccessDeniedError("You cannot modify this field")
            raise FieldNotFoundError(f"Field {field_id} not found")

        return record.field

    async def create_cycle(
        self,
        *,
        field_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        crop_code: str,
        variety: str | None = None,
        planting_date=None,
        expected_harvest_date=None,
        current_stage: str | None = None,
        irrigation_type: str | None = None,
        status: str = CropCycleStatus.PLANNED.value,
        request_id: str | None = None,
    ) -> CropCycle:
        await self._authorized_field(
            field_id=field_id, farmer_id=farmer_id, role_codes=role_codes, write=True
        )

        # A field grows one crop at a time; two concurrent ACTIVE cycles would
        # make every downstream per-cycle metric ambiguous.
        if status == CropCycleStatus.ACTIVE.value:
            existing = await self._repository.get_active_for_field(field_id)
            if existing is not None:
                raise ActiveCropCycleExistsError(
                    f"Field already has an active crop cycle ({existing.id})"
                )

        cycle = await self._repository.create(
            field_id=field_id,
            crop_code=crop_code,
            variety=variety,
            planting_date=planting_date,
            expected_harvest_date=expected_harvest_date,
            current_stage=current_stage,
            irrigation_type=irrigation_type,
            status=status,
        )

        await self._outbox.append(
            events.crop_cycle_started(
                cycle_id=cycle.id,
                field_id=field_id,
                crop_code=crop_code,
                planting_date=planting_date.isoformat() if planting_date else None,
            )
        )
        await self._audit.record(
            actor_user_id=actor_user_id,
            action="crop_cycle.create",
            entity_type="farm.crop_cycles",
            entity_id=cycle.id,
            context={"field_id": str(field_id), "crop_code": crop_code},
            request_id=request_id,
        )
        return cycle

    async def get_cycle(
        self, *, cycle_id: uuid.UUID, farmer_id: uuid.UUID, role_codes: set[str]
    ) -> CropCycle:
        cycle = await self._repository.get_by_id(cycle_id)
        if cycle is None:
            raise CropCycleNotFoundError(f"Crop cycle {cycle_id} not found")

        await self._authorized_field(
            field_id=cycle.field_id,
            farmer_id=farmer_id,
            role_codes=role_codes,
            write=False,
        )
        return cycle

    async def list_cycles_for_field(
        self,
        *,
        field_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
    ) -> list[CropCycle]:
        await self._authorized_field(
            field_id=field_id, farmer_id=farmer_id, role_codes=role_codes, write=False
        )
        return await self._repository.list_by_field(
            field_id=field_id, limit=limit, cursor=cursor
        )

    async def update_cycle(
        self,
        *,
        cycle_id: uuid.UUID,
        farmer_id: uuid.UUID,
        role_codes: set[str],
        actor_user_id: uuid.UUID,
        changes: dict,
        expected_version: int | None = None,
        request_id: str | None = None,
    ) -> CropCycle:
        current = await self._repository.get_by_id(cycle_id)
        if current is None:
            raise CropCycleNotFoundError(f"Crop cycle {cycle_id} not found")

        await self._authorized_field(
            field_id=current.field_id,
            farmer_id=farmer_id,
            role_codes=role_codes,
            write=True,
        )

        applied = {key: value for key, value in changes.items() if value is not None}
        if not applied:
            return current

        new_status = applied.get("status")
        if new_status == CropCycleStatus.ACTIVE.value and current.status != new_status:
            existing = await self._repository.get_active_for_field(current.field_id)
            if existing is not None and existing.id != cycle_id:
                raise ActiveCropCycleExistsError(
                    f"Field already has an active crop cycle ({existing.id})"
                )

        updated = await self._repository.update_attributes(
            cycle_id=cycle_id, values=applied, expected_version=expected_version
        )
        if updated is None:
            raise CropCycleVersionConflictError(
                "Crop cycle was modified by someone else; refresh and retry"
            )

        if new_status is not None and new_status != current.status:
            await self._outbox.append(
                events.crop_cycle_status_changed(
                    cycle_id=cycle_id,
                    field_id=current.field_id,
                    old_status=current.status,
                    new_status=new_status,
                )
            )

        await self._audit.record(
            actor_user_id=actor_user_id,
            action="crop_cycle.update",
            entity_type="farm.crop_cycles",
            entity_id=cycle_id,
            context={"changed_fields": sorted(applied)},
            request_id=request_id,
        )
        return updated
