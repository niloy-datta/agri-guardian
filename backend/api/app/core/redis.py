"""Redis client lifecycle.

Redis is used only for cache, Celery broker/backend, rate limiting, and
distributed locks. It is never the source of truth for domain data - see
`docs/BACKEND_ARCHITECTURE.md`.
"""

from redis.asyncio import Redis

_client: Redis | None = None


def init_redis(redis_url: str) -> Redis:
    global _client
    _client = Redis.from_url(redis_url, decode_responses=True)
    return _client


async def dispose_redis() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
    _client = None


def get_redis_client() -> Redis:
    if _client is None:
        raise RuntimeError("Redis client is not initialized. Call init_redis() during startup.")
    return _client


async def get_redis() -> Redis:
    """FastAPI dependency."""
    return get_redis_client()


async def ping_redis() -> bool:
    if _client is None:
        return False
    try:
        return bool(await _client.ping())
    except Exception:
        return False
