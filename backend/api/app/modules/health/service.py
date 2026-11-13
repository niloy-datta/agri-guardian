"""Health checks.

Every readiness probe here issues a real round-trip: `SELECT 1` against
Postgres and `PING` against Redis. Nothing reports healthy on the strength
of configuration alone - an instance whose engine was never initialised, or
whose database went away, must fail the probe so it is pulled out of
rotation rather than serving 500s.
"""

from app.core.database import ping_database
from app.core.redis import ping_redis
from app.modules.health.schemas import DependencyStatus


async def check_database() -> DependencyStatus:
    healthy = await ping_database()
    return DependencyStatus(
        name="postgresql",
        healthy=healthy,
        detail=None if healthy else "SELECT 1 failed or engine is not initialized",
    )


async def check_redis() -> DependencyStatus:
    healthy = await ping_redis()
    return DependencyStatus(
        name="redis",
        healthy=healthy,
        detail=None if healthy else "PING failed or client is not initialized",
    )


async def collect_readiness() -> tuple[bool, list[DependencyStatus]]:
    """Probes every dependency and reports the aggregate verdict.

    All probes run even if the first one fails, so an operator sees the
    whole picture from a single request instead of one failure at a time.
    """
    dependencies = [await check_database(), await check_redis()]
    return all(dependency.healthy for dependency in dependencies), dependencies
