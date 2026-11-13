"""Advisory HTTP layer.

Dependencies are wired locally in this module rather than added to
`app/core/dependencies.py`, since a NASA POWER client's lifecycle
(open per request, close after) is specific to this one integration.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import get_settings
from app.core.dependencies import CurrentUser
from app.integrations.nasa.client import NasaPowerClient, NasaPowerError, NasaPowerValidationError
from app.integrations.nasa.power_cache import (
    NasaEvidenceIntegrityError,
    NasaPowerCache,
    NasaPowerUnavailableOfflineError,
)
from app.modules.advisory.pilots.rajshahi_aman import RAJSHAHI_AMAN_PILOT
from app.modules.advisory.schemas import (
    PilotPlantingWindowRequest,
    PilotPlantingWindowResponse,
    PlantingWindowRequest,
    PlantingWindowResponse,
)
from app.modules.advisory.service import AdvisoryService

router = APIRouter(prefix="/advisory", tags=["advisory"])


async def get_nasa_power_client() -> AsyncIterator[NasaPowerClient]:
    settings = get_settings()
    client = NasaPowerClient(
        base_url=settings.nasa_power_base_url,
        timeout_seconds=settings.nasa_power_timeout_seconds,
    )
    try:
        yield client
    finally:
        await client.aclose()


def get_nasa_power_cache(
    client: Annotated[NasaPowerClient, Depends(get_nasa_power_client)],
) -> NasaPowerCache:
    settings = get_settings()
    return NasaPowerCache(
        client=client,
        cache_dir=settings.resolve_nasa_power_cache_dir(),
        fixture_dir=settings.resolve_nasa_power_fixture_dir(),
        offline=settings.nasa_power_offline,
    )


def get_advisory_service(
    cache: Annotated[NasaPowerCache, Depends(get_nasa_power_cache)],
) -> AdvisoryService:
    return AdvisoryService(cache=cache)


AdvisoryServiceDep = Annotated[AdvisoryService, Depends(get_advisory_service)]


@router.post("/planting-window", response_model=PlantingWindowResponse)
async def planting_window(
    payload: PlantingWindowRequest,
    _user: CurrentUser,
    service: AdvisoryServiceDep,
) -> PlantingWindowResponse:
    """Deterministic for the same evidence and assumptions - no LLM call
    exists anywhere on this path. See `app/compute/agro.py` for the
    equations and `app/modules/advisory/service.py` for how NASA POWER
    evidence is retrieved and assembled around them.
    """
    try:
        return await service.compute_planting_window(payload)
    except NasaPowerValidationError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except NasaPowerUnavailableOfflineError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    except NasaPowerError as exc:
        # Request/response failures talking to NASA POWER itself - this
        # service has no evidence to fall back to, so it reports the
        # upstream failure rather than inventing a result.
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc


@router.post("/pilots/rajshahi-aman", response_model=PilotPlantingWindowResponse)
async def rajshahi_aman_pilot(
    _payload: PilotPlantingWindowRequest,
    _user: CurrentUser,
    service: AdvisoryServiceDep,
) -> PilotPlantingWindowResponse:
    """The single verified Rajshahi Aman pilot. Every scientific
    assumption (coordinate, baseline crop calendar, historical periods,
    onset definition) is backend-controlled and sourced in
    `docs/references/rajshahi_aman_pilot.md` -
    `PilotPlantingWindowRequest` accepts no latitude, longitude, or
    base-temperature override from the client.
    """
    try:
        return await service.compute_pilot_planting_window(RAJSHAHI_AMAN_PILOT)
    except NasaEvidenceIntegrityError as exc:
        # A tampered or unmanifested fixture - never served, so this is a
        # hard failure, not a degraded response.
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc
    except NasaPowerValidationError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except NasaPowerUnavailableOfflineError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    except NasaPowerError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
