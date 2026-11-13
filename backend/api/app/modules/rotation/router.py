"""Location intelligence, dataset provenance and crop-rotation HTTP layer.

Every route requires an authenticated user. Field-scoped routes authorise
through `FieldService.get_field` (404 for another farmer's field). No
provider credential ever appears in a response.
"""

from __future__ import annotations

import json
import uuid
from collections.abc import AsyncIterator
from dataclasses import asdict
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import CurrentUser, DbSession
from app.integrations.dataset_evidence import CMR_EVIDENCE
from app.integrations.datasets import DATASETS
from app.integrations.hub import IntegrationHub
from app.integrations.reference import bd_locations as loc
from app.integrations.reference.crop_calendars import calendars_for_district
from app.modules.farmers.repository import FarmerRepository
from app.modules.farmers.service import FarmerService
from app.modules.fields.repository import FieldRepository
from app.modules.fields.service import FieldService
from app.modules.rotation import service as svc
from app.modules.rotation.schemas import (
    AdHocScenarioRequest,
    CalendarWindowOut,
    DatasetOut,
    DistrictOut,
    LocationOut,
    PointIn,
    PolygonIn,
    RotationOut,
    RotationProfileIn,
    RotationProfileOut,
    ScenarioRequest,
)

router = APIRouter(prefix="/intelligence", tags=["intelligence"])
field_router = APIRouter(prefix="/fields/{field_id}", tags=["rotation"])

_EVIDENCE_FILE = Path(__file__).resolve().parents[4] / "docs" / "evidence" / "live_acquisition.json"


async def get_hub() -> AsyncIterator[IntegrationHub]:
    hub = IntegrationHub()
    try:
        yield hub
    finally:
        await hub.aclose()


HubDep = Annotated[IntegrationHub, Depends(get_hub)]


def _location_out(r: loc.LocationResolution) -> LocationOut:
    windows = calendars_for_district(r.district) if r.district else []
    return LocationOut(
        latitude=r.latitude, longitude=r.longitude, in_bangladesh=r.in_bangladesh,
        district=r.district, division=r.division, near_boundary=r.near_boundary,
        bamis_region=windows[0].region if windows else None,
        calendar_crops=sorted({w.crop for w in windows}),
    )  # fmt: skip


@router.get("/datasets", response_model=list[DatasetOut])
async def list_datasets(user: CurrentUser) -> list[DatasetOut]:
    """All 30 catalogued datasets with verified identifiers and current status."""
    status_map: dict[str, dict[str, str]] = {}
    updated = None
    if _EVIDENCE_FILE.exists():
        try:
            evidence = json.loads(_EVIDENCE_FILE.read_text(encoding="utf-8"))
            status_map = evidence.get("results", {})
            updated = evidence.get("generated_at")
        except (OSError, ValueError, AttributeError):
            # An absent or invalid evidence record is not evidence of success.
            pass
    out = []
    for d in DATASETS:
        ev = CMR_EVIDENCE.get((d.cmr_short_name or "", d.cmr_version or ""))
        st = status_map.get(f"{d.number:02d}", {})
        recorded = st.get("status", "NOT_CHECKED")
        if st.get("key") != d.key:
            recorded = "NOT_CHECKED"
            st = {}
        blocker = {
            "DISCOVERED": "Catalogue discovery only; observations not verified as acquired.",
            "NO_DATA": "The recorded request returned no usable values.",
            "FAILED": "Acquisition failed; inspect the acquisition record.",
            "BLOCKED": "Acquisition blocked; inspect provider credentials or permissions.",
            "NOT_CHECKED": "No acquisition evidence recorded for this dataset.",
        }.get(recorded, "")
        out.append(DatasetOut(
            number=d.number, key=d.key, name=d.name, access=d.access.value, use=d.use,
            caveat=d.caveat, resolution=d.resolution,
            product=d.cmr_short_name and f"{d.cmr_short_name} v{d.cmr_version}",
            doi=ev.doi if ev else None, id_confirmed=d.id_confirmed,
            status=recorded, blocker=blocker, last_updated=updated if st else None,
            acquired="RECORDED" if recorded == "ACQUIRED" else "NOT_VERIFIED",
        ))  # fmt: skip
    return out


@router.get("/locations/divisions", response_model=list[str])
async def list_divisions(user: CurrentUser) -> list[str]:
    return loc.divisions()


@router.get("/locations/districts", response_model=list[DistrictOut])
async def list_districts(
    user: CurrentUser, division: str | None = Query(default=None)
) -> list[DistrictOut]:
    out = []
    for d in loc.districts():
        if division and d.division.lower() != division.lower():
            continue
        windows = calendars_for_district(d.name)
        out.append(DistrictOut(name=d.name, division=d.division, geonames_id=d.geonames_id,
                               latitude=d.centroid[0], longitude=d.centroid[1],
                               bamis_region=windows[0].region if windows else None))  # fmt: skip
    return out


@router.post("/locations/resolve", response_model=LocationOut)
async def resolve_location(payload: PointIn, user: CurrentUser) -> LocationOut:
    return _location_out(loc.resolve_point(payload.latitude, payload.longitude))


@router.post("/locations/resolve-field", response_model=LocationOut)
async def resolve_field_polygon(payload: PolygonIn, user: CurrentUser) -> LocationOut:
    try:
        return _location_out(loc.resolve_field([list(p) for p in payload.ring]))
    except loc.OutsideBangladeshError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc


@router.get("/calendars", response_model=list[CalendarWindowOut])
async def crop_calendars(
    user: CurrentUser, district: str = Query(min_length=2)
) -> list[CalendarWindowOut]:
    try:
        loc.get_district(district)
    except KeyError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"unknown district {district!r}") from exc
    return [
        CalendarWindowOut(
            crop=w.crop,
            region=w.region,
            start=f"{w.start[0]:02d}-{w.start[1]:02d}",
            end=f"{w.end[0]:02d}-{w.end[1]:02d}",
            duration_days=w.duration_days,
            verified=w.verified,
            qa_note=w.qa_note,
            source_url=w.source_url,
        )  # fmt: skip
        for w in calendars_for_district(district, include_unverified=True)
    ]


def _rotation_out(bundle: svc.EvidenceBundle, result: object) -> RotationOut:
    from app.compute.rotation_engine import RotationResult  # noqa: PLC0415

    assert isinstance(result, RotationResult)
    return RotationOut(
        status=result.status.value,
        location=_location_out(bundle.location),
        scenarios=[{
            "crops": list(s.crops), "overlap_days": s.overlap_days,
            "irrigation_dependent": list(s.irrigation_dependent),
            "unknown_water_need": list(s.unknown_water_need), "rice_seasons": s.rice_seasons,
            "has_pulse": s.has_pulse, "weakest_gaez_index": s.weakest_gaez_index,
            "claims": [asdict(c) for c in s.claims],
        } for s in result.scenarios],
        excluded=[{"crop": c, "reason": r} for c, r in result.excluded],
        unsupported_priorities=list(result.unsupported_priorities),
        reasons=list(result.reasons),
        evidence=[asdict(i) for i in bundle.items],
        retrieved_at=bundle.retrieved_at,
    )  # fmt: skip


@router.post("/rotation-scenarios", response_model=RotationOut)
async def adhoc_rotation(
    payload: AdHocScenarioRequest, user: CurrentUser, hub: HubDep
) -> RotationOut:
    """Scenario comparison for a point (before a field is saved)."""
    r = loc.resolve_point(payload.latitude, payload.longitude)
    if not r.in_bangladesh:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "location is outside Bangladesh")
    bundle = await svc.build_evidence(hub, r)
    result = svc.rotate(bundle, irrigation_access=payload.irrigation_access or "none",
                        priorities=tuple(payload.preferred_outcomes or ()),
                        max_overlap_days=payload.max_overlap_days)  # fmt: skip
    return _rotation_out(bundle, result)


async def _owned_field(field_id: uuid.UUID, user: CurrentUser, session: DbSession):
    farmer = await FarmerService(FarmerRepository(session)).ensure_profile_for_user(user_id=user.id)
    from app.modules.admin.repository import AuditRepository, OutboxRepository  # noqa: PLC0415

    record = await FieldService(FieldRepository(session), OutboxRepository(session),
                                AuditRepository(session)).get_field(
        field_id=field_id, farmer_id=farmer.id, role_codes=user.role_codes)  # fmt: skip
    return farmer, record


@field_router.get("/rotation-profile", response_model=RotationProfileOut)
async def get_rotation_profile(
    field_id: uuid.UUID, user: CurrentUser, session: DbSession
) -> RotationProfileOut:
    await _owned_field(field_id, user, session)
    row = await svc.RotationProfileRepository(session).get(field_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "no rotation profile for this field")
    return RotationProfileOut(
        field_id=str(row.field_id), version=row.version, previous_crops=row.previous_crops,
        irrigation_access=row.irrigation_access, budget_bdt=row.budget_bdt,
        preferred_outcomes=row.preferred_outcomes,
        consent_to_personalise=row.consent_to_personalise,
    )  # fmt: skip


@field_router.put("/rotation-profile", response_model=RotationProfileOut)
async def put_rotation_profile(
    field_id: uuid.UUID, payload: RotationProfileIn, user: CurrentUser, session: DbSession
) -> RotationProfileOut:
    farmer, _ = await _owned_field(field_id, user, session)
    row = await svc.RotationProfileRepository(session).upsert(
        field_id=field_id, farmer_id=farmer.id, previous_crops=payload.previous_crops,
        irrigation_access=payload.irrigation_access, budget_bdt=payload.budget_bdt,
        preferred_outcomes=list(payload.preferred_outcomes),
        consent=payload.consent_to_personalise,
    )  # fmt: skip
    await session.commit()
    return RotationProfileOut(field_id=str(row.field_id), version=row.version,
                              **payload.model_dump())  # fmt: skip


@field_router.post("/rotation-scenarios", response_model=RotationOut)
async def field_rotation(
    field_id: uuid.UUID,
    payload: ScenarioRequest,
    user: CurrentUser,
    session: DbSession,
    hub: HubDep,
) -> RotationOut:
    """Scenario comparison for a saved field, using its polygon and stored profile."""
    _, record = await _owned_field(field_id, user, session)
    ring = record.boundary_geojson["coordinates"][0]
    try:
        r = loc.resolve_field([list(p) for p in ring])
    except loc.OutsideBangladeshError as exc:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(exc)) from exc
    profile = await svc.RotationProfileRepository(session).get(field_id)
    irrigation = payload.irrigation_access or (profile.irrigation_access if profile else "none")
    priorities = payload.preferred_outcomes or (profile.preferred_outcomes if profile else [])
    bundle = await svc.build_evidence(hub, r)
    result = svc.rotate(bundle, irrigation_access=irrigation, priorities=tuple(priorities),
                        max_overlap_days=payload.max_overlap_days)  # fmt: skip
    return _rotation_out(bundle, result)
