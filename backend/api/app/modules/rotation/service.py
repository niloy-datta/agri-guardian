"""Rotation evidence assembly + profile persistence.

`build_evidence()` gathers REAL evidence for one location, per dataset, and
records for each item whether it was obtained, its source URL, resolution
and caveat. A provider failure never aborts the request: that item is
marked UNAVAILABLE with the reason, and the engine works with what is left
(returning INSUFFICIENT_EVIDENCE when too little remains).
"""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.compute.rotation_engine import CropEvidence, RotationResult, generate_rotations
from app.integrations.common.errors import IntegrationError
from app.integrations.fao.gaez import CROP_CODES
from app.integrations.hub import IntegrationHub
from app.integrations.reference.bd_locations import LocationResolution
from app.integrations.reference.crop_calendars import calendars_for_district
from app.modules.rotation.models import RotationProfile


@dataclass(slots=True)
class EvidenceItem:
    dataset: int
    name: str
    status: str  # AVAILABLE | UNAVAILABLE | NOT_APPLICABLE
    resolution: str
    source_url: str
    caveat: str
    values: dict[str, Any] = field(default_factory=dict)
    reason: str = ""


@dataclass(slots=True)
class EvidenceBundle:
    location: LocationResolution
    items: list[EvidenceItem]
    crops: list[CropEvidence]
    retrieved_at: str


async def _gaez_pair(
    hub: IntegrationHub, crop: str, lat: float, lon: float
) -> tuple[int | None, int | None, str]:
    rain = await hub.gaez.suitability(
        crop=crop, latitude=lat, longitude=lon, water_supply="rainfed_high"
    )
    irr = await hub.gaez.suitability(
        crop=crop, latitude=lat, longitude=lon, water_supply="irrigated_high"
    )
    return rain.index, irr.index, f"{rain.source_url} ; {irr.source_url}"


async def build_evidence(hub: IntegrationHub, location: LocationResolution) -> EvidenceBundle:
    lat, lon = location.latitude, location.longitude
    items: list[EvidenceItem] = []
    windows = calendars_for_district(location.district) if location.district else []
    items.append(EvidenceItem(
        7, "BAMIS / DAE crop weather calendar", "AVAILABLE" if windows else "UNAVAILABLE",
        "BAMIS region (multi-district)", "https://www.bamis.gov.bd/",
        "Regional 2019 calendars; windows may include nursery period.",
        {"region": windows[0].region if windows else None, "crops": [w.crop for w in windows]},
        "" if windows else "no BAMIS calendar for this district",
    ))  # fmt: skip

    crops: list[CropEvidence] = []
    gaez_errors: list[str] = []
    gaez_values: dict[str, Any] = {}
    for w in windows:
        if w.crop not in CROP_CODES:
            crops.append(CropEvidence(w.crop, w))
            continue
        try:
            r, i, src = await _gaez_pair(hub, w.crop, lat, lon)
            crops.append(CropEvidence(w.crop, w, r, i, src))
            gaez_values[w.crop] = {"rainfed_high": r, "irrigated_high": i}
        except IntegrationError as exc:
            gaez_errors.append(f"{w.crop}: {exc}")
            crops.append(CropEvidence(w.crop, w))
    items.append(EvidenceItem(
        6, "FAO GAEZ v5 crop suitability (RES05-SXX)",
        "AVAILABLE" if gaez_values else "UNAVAILABLE", "5 arc-min (~9 km)",
        "https://storage.googleapis.com/fao-gismgr-gaez-v5-data/DATA/GAEZ-V5/",
        "Modelled index, 2001-2020 climate; not yield. Lentil/jute not covered.",
        gaez_values, "; ".join(gaez_errors),
    ))  # fmt: skip

    async def soil() -> EvidenceItem:
        bbox = (lon - 0.01, lat - 0.01, lon + 0.01, lat + 0.01)
        vals: dict[str, Any] = {}
        for prop in ("phh2o", "soc", "nitrogen"):
            st = await hub.soilgrids.fetch_wcs_stats(property=prop, depth="0-5cm", bbox=bbox)
            vals[prop] = {
                "mean": st.mean,
                "valid_pixels": st.valid_pixels,
                "total_pixels": st.total_pixels,
            }
        return EvidenceItem(5, "ISRIC SoilGrids 2.0 (WCS)", "AVAILABLE", "250 m",
                            "https://maps.isric.org/", "Modelled estimates, 0-5 cm; context only, "
                            "no suitability threshold applied.", vals)  # fmt: skip

    async def climate() -> EvidenceItem:
        r = await hub.power_extended.fetch_climatology(latitude=lat, longitude=lon,
                                                       parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"))  # fmt: skip
        return EvidenceItem(20, "NASA POWER climatology (monthly baseline)", "AVAILABLE",
                            "0.5 x 0.625 deg", "https://power.larc.nasa.gov/",
                            "Reanalysis grid cell, not a station.", {"monthly": r.monthly, "units": r.units})  # fmt: skip

    for name, number, coro in (("soil", 5, soil()), ("climate", 20, climate())):
        try:
            items.append(await asyncio.wait_for(coro, timeout=90))
        except (IntegrationError, TimeoutError) as exc:
            items.append(
                EvidenceItem(number, name, "UNAVAILABLE", "", "", "", reason=str(exc)[:300])
            )
    return EvidenceBundle(location, items, crops, datetime.now(UTC).isoformat())


def rotate(bundle: EvidenceBundle, *, irrigation_access: str, priorities: tuple[str, ...],
           max_overlap_days: int) -> RotationResult:  # fmt: skip
    return generate_rotations(
        bundle.crops,
        has_irrigation=irrigation_access != "none",
        priorities=priorities,
        max_overlap_days=max_overlap_days,
    )


class RotationProfileRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, field_id: uuid.UUID) -> RotationProfile | None:
        return await self._session.scalar(
            select(RotationProfile).where(RotationProfile.field_id == field_id)
        )

    async def upsert(
        self, *, field_id: uuid.UUID, farmer_id: uuid.UUID, previous_crops: list[str],
        irrigation_access: str, budget_bdt: Decimal | None, preferred_outcomes: list[str],
        consent: bool,
    ) -> RotationProfile:  # fmt: skip
        row = await self.get(field_id)
        now = datetime.now(UTC)
        if row is None:
            row = RotationProfile(field_id=field_id, farmer_id=farmer_id)
            self._session.add(row)
        else:
            row.version += 1
        row.previous_crops = previous_crops
        row.irrigation_access = irrigation_access
        row.budget_bdt = budget_bdt
        row.preferred_outcomes = preferred_outcomes
        if consent and not row.consent_to_personalise:
            row.consent_recorded_at = now
        if not consent:
            row.consent_recorded_at = None
        row.consent_to_personalise = consent
        await self._session.flush()
        return row
