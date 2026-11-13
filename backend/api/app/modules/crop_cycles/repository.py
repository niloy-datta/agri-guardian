"""Database access for crop cycles."""

import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.crop_cycles.models import CropCycle
from app.shared.enums import CropCycleStatus


class CropCycleRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        *,
        field_id: uuid.UUID,
        crop_code: str,
        variety: str | None,
        planting_date,
        expected_harvest_date,
        current_stage: str | None,
        irrigation_type: str | None,
        status: str,
    ) -> CropCycle:
        cycle = CropCycle(
            field_id=field_id,
            crop_code=crop_code,
            variety=variety,
            planting_date=planting_date,
            expected_harvest_date=expected_harvest_date,
            current_stage=current_stage,
            irrigation_type=irrigation_type,
            status=status,
        )
        self._session.add(cycle)
        await self._session.flush()
        await self._session.refresh(cycle)
        return cycle

    async def get_by_id(self, cycle_id: uuid.UUID) -> CropCycle | None:
        result = await self._session.execute(
            select(CropCycle).where(CropCycle.id == cycle_id)
        )
        return result.scalar_one_or_none()

    async def list_by_field(
        self,
        *,
        field_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
    ) -> list[CropCycle]:
        stmt = select(CropCycle).where(CropCycle.field_id == field_id)

        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    CropCycle.created_at < cursor_created_at,
                    and_(
                        CropCycle.created_at == cursor_created_at,
                        CropCycle.id < cursor_id,
                    ),
                )
            )

        stmt = stmt.order_by(CropCycle.created_at.desc(), CropCycle.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return list(result.scalars().all())

    async def get_active_for_field(self, field_id: uuid.UUID) -> CropCycle | None:
        stmt = select(CropCycle).where(
            CropCycle.field_id == field_id,
            CropCycle.status == CropCycleStatus.ACTIVE.value,
        )
        result = await self._session.execute(stmt)
        return result.scalars().first()

    async def update_attributes(
        self,
        *,
        cycle_id: uuid.UUID,
        values: dict,
        expected_version: int | None = None,
    ) -> CropCycle | None:
        stmt = update(CropCycle).where(CropCycle.id == cycle_id)
        if expected_version is not None:
            stmt = stmt.where(CropCycle.version == expected_version)

        stmt = stmt.values(**values, version=CropCycle.version + 1).returning(CropCycle.id)
        result = await self._session.execute(stmt)
        if result.scalar_one_or_none() is None:
            return None

        return await self.get_by_id(cycle_id)
