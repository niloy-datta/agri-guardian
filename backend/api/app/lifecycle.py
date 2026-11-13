"""Application startup/shutdown.

Owns the process-wide resources the request path depends on: the async
SQLAlchemy engine and the Redis client. Both are created once here and torn
down in reverse order, so `app.core.database` / `app.core.redis` can keep
their module-level singletons and every dependency resolves without
per-request connection setup.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import get_settings
from app.core.database import dispose_engine, init_engine
from app.core.logging import get_logger
from app.core.redis import dispose_redis, init_redis

logger = get_logger("lifecycle")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()

    init_engine(settings.database_url)
    init_redis(settings.redis_url)
    logger.info(
        "startup_complete",
        app_env=settings.app_env,
        api_prefix=settings.api_v1_prefix,
    )

    try:
        yield
    finally:
        # Reverse order of acquisition: Redis first, then the DB engine, so a
        # slow pool drain never leaves the cache client dangling.
        await dispose_redis()
        await dispose_engine()
        logger.info("shutdown_complete")
