"""Health HTTP layer.

Unauthenticated on purpose: these are the endpoints a load balancer, a
Kubernetes probe or `docker compose` healthcheck calls, none of which hold
a Supabase token.
"""

from fastapi import APIRouter, Response, status

from app import __version__
from app.core.config import get_settings
from app.modules.health import service
from app.modules.health.schemas import HealthResponse, ReadinessResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("", response_model=HealthResponse)
async def health() -> HealthResponse:
    """Liveness: the process is up and serving. Touches no dependency."""
    settings = get_settings()
    return HealthResponse(
        status="ok",
        app=settings.app_name,
        environment=settings.app_env,
        version=__version__,
    )


@router.get(
    "/ready",
    response_model=ReadinessResponse,
    responses={status.HTTP_503_SERVICE_UNAVAILABLE: {"model": ReadinessResponse}},
)
async def ready(response: Response) -> ReadinessResponse:
    """Readiness: actually queries Postgres and Redis.

    Returns 503 when any dependency is down, so traffic is routed away
    instead of failing inside a handler.
    """
    is_ready, dependencies = await service.collect_readiness()
    if not is_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return ReadinessResponse(ready=is_ready, dependencies=dependencies)
