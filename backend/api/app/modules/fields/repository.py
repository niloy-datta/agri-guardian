"""Database access for fields.

Geometry never round-trips through Python: PostGIS builds it from GeoJSON,
derives the centroid and the geodesic area, and serializes it back with
`ST_AsGeoJSON`. That keeps the projection maths in one authoritative place.
"""

import json
import uuid
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal

from geoalchemy2 import Geography, Geometry
from sqlalchemy import Select, and_, cast, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.fields.models import Field
from app.shared.enums import FieldStatus

# Reusable column types for explicit geometry/geography casts.
_POINT_GEOMETRY = Geometry(geometry_type="POINT", srid=4326)
_POLYGON_GEOGRAPHY = Geography(geometry_type="POLYGON", srid=4326)
_POINT_GEOGRAPHY = Geography(geometry_type="POINT", srid=4326)


@dataclass(slots=True)
class FieldRecord:
    """A field plus its PostGIS-derived representations."""

    field: Field
    boundary_geojson: dict
    centroid_longitude: float
    centroid_latitude: float


def _boundary_expression(geojson_str: str):
    """Geometry built from GeoJSON, explicitly pinned to EPSG:4326."""
    return func.ST_SetSRID(func.ST_GeomFromGeoJSON(geojson_str), 4326)


class FieldRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _select_with_geo(self) -> Select:
        # centroid is geography; cast back to geometry to read X/Y ordinates.
        centroid_geom = cast(Field.centroid, _POINT_GEOMETRY)
        return select(
            Field,
            func.ST_AsGeoJSON(Field.boundary).label("boundary_geojson"),
            func.ST_X(centroid_geom).label("lon"),
            func.ST_Y(centroid_geom).label("lat"),
        )

    @staticmethod
    def _to_record(row) -> FieldRecord:
        return FieldRecord(
            field=row[0],
            boundary_geojson=json.loads(row[1]),
            centroid_longitude=float(row[2]),
            centroid_latitude=float(row[3]),
        )

    async def create(
        self,
        *,
        farmer_id: uuid.UUID,
        name: str,
        boundary_geojson: dict,
        country_code: str,
        region: str | None,
        district: str | None,
        upazila: str | None,
        field_id: uuid.UUID | None = None,
    ) -> FieldRecord:
        geojson_str = json.dumps(boundary_geojson, separators=(",", ":"))
        boundary = _boundary_expression(geojson_str)

        field = Field(
            id=field_id or uuid.uuid4(),
            farmer_id=farmer_id,
            name=name,
            boundary=boundary,
            # Centroid of the polygon, stored as geography for metre-based
            # distance queries without picking a local projection.
            centroid=cast(func.ST_Centroid(boundary), _POINT_GEOGRAPHY),
            # ST_Area over geography returns square metres on the spheroid.
            area_sq_m=func.ST_Area(cast(boundary, _POLYGON_GEOGRAPHY)),
            country_code=country_code,
            region=region,
            district=district,
            upazila=upazila,
            status=FieldStatus.ACTIVE.value,
        )
        self._session.add(field)
        await self._session.flush()

        record = await self.get_by_id(field.id)
        if record is None:  # pragma: no cover - the row was just inserted
            raise RuntimeError(f"Field {field.id} vanished within its own transaction")
        return record

    async def check_geometry_validity(self, boundary_geojson: dict) -> tuple[bool, str]:
        """Asks PostGIS whether the polygon is topologically valid.

        Catches self-intersections and similar defects that structural
        JSON validation cannot see, before they reach a table with a
        geometry column.
        """
        geojson_str = json.dumps(boundary_geojson, separators=(",", ":"))
        boundary = _boundary_expression(geojson_str)
        stmt = select(func.ST_IsValid(boundary), func.ST_IsValidReason(boundary))
        result = await self._session.execute(stmt)
        is_valid, reason = result.one()
        return bool(is_valid), str(reason)

    async def get_by_id(self, field_id: uuid.UUID) -> FieldRecord | None:
        stmt = self._select_with_geo().where(Field.id == field_id)
        result = await self._session.execute(stmt)
        row = result.first()
        return self._to_record(row) if row else None

    async def list_by_farmer(
        self,
        *,
        farmer_id: uuid.UUID,
        limit: int,
        cursor: tuple[datetime, uuid.UUID] | None = None,
        include_archived: bool = False,
    ) -> list[FieldRecord]:
        """Newest-first keyset pagination on `(created_at, id)`.

        Offset pagination would degrade as a farmer's history grows and can
        skip or repeat rows when new fields are inserted mid-scan.
        """
        stmt = self._select_with_geo().where(Field.farmer_id == farmer_id)

        if not include_archived:
            stmt = stmt.where(Field.status != FieldStatus.ARCHIVED.value)

        if cursor is not None:
            cursor_created_at, cursor_id = cursor
            stmt = stmt.where(
                or_(
                    Field.created_at < cursor_created_at,
                    and_(Field.created_at == cursor_created_at, Field.id < cursor_id),
                )
            )

        stmt = stmt.order_by(Field.created_at.desc(), Field.id.desc()).limit(limit)
        result = await self._session.execute(stmt)
        return [self._to_record(row) for row in result.all()]

    async def update_attributes(
        self,
        *,
        field_id: uuid.UUID,
        values: dict,
        expected_version: int | None = None,
    ) -> FieldRecord | None:
        """Applies a partial update, bumping `version`.

        When `expected_version` is supplied the update is conditional, so a
        stale offline edit fails instead of clobbering a newer server state.
        """
        stmt = update(Field).where(Field.id == field_id)
        if expected_version is not None:
            stmt = stmt.where(Field.version == expected_version)

        stmt = stmt.values(**values, version=Field.version + 1).returning(Field.id)
        result = await self._session.execute(stmt)
        if result.scalar_one_or_none() is None:
            return None

        return await self.get_by_id(field_id)

    async def total_area_for_farmer(self, farmer_id: uuid.UUID) -> Decimal:
        stmt = select(func.coalesce(func.sum(Field.area_sq_m), 0)).where(
            Field.farmer_id == farmer_id,
            Field.status != FieldStatus.ARCHIVED.value,
        )
        result = await self._session.execute(stmt)
        return Decimal(result.scalar_one())
