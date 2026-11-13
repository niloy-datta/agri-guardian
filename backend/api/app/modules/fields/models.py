"""Field ORM model (schema: `farm`).

A field is a real polygon in EPSG:4326, never a bare lat/lng pair - every
downstream capability (NDVI zonal statistics, rainfall aggregation,
irrigation planning) needs the actual parcel shape. `centroid` is a
derived geography point kept for cheap proximity queries, and `area_sq_m`
is computed by PostGIS on write so client and server never disagree.
"""

import uuid
from decimal import Decimal

from geoalchemy2 import Geography, Geometry
from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Index,
    Numeric,
    String,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.shared.enums import FieldStatus, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class Field(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "fields"
    __table_args__ = (
        CheckConstraint(
            "status IN ('" + "','".join(values(FieldStatus)) + "')",
            name="ck_farm_fields_status",
        ),
        CheckConstraint("area_sq_m > 0", name="ck_farm_fields_area_positive"),
        Index("ix_farm_fields_boundary_gist", "boundary", postgresql_using="gist"),
        Index("ix_farm_fields_centroid_gist", "centroid", postgresql_using="gist"),
        # Composite index backing the cursor-paginated "my fields" listing.
        Index("ix_farm_fields_farmer_created", "farmer_id", "created_at", "id"),
        Index("ix_farm_fields_country_region", "country_code", "region"),
        {"schema": "farm"},
    )

    farmer_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("farm.farmer_profiles.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)

    # spatial_index=False: the GiST indexes are declared explicitly above so
    # Alembic and the model agree on their names.
    boundary: Mapped[object] = mapped_column(
        Geometry(geometry_type="POLYGON", srid=4326, spatial_index=False),
        nullable=False,
    )
    centroid: Mapped[object] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False),
        nullable=False,
    )
    area_sq_m: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)

    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    region: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
    upazila: Mapped[str | None] = mapped_column(String(120), nullable=True)

    status: Mapped[str] = mapped_column(
        String(24), nullable=False, default=FieldStatus.ACTIVE.value
    )
