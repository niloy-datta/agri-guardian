"""Exercise the OTP security script against real Redis, not a Lua imitation."""

import uuid
from collections.abc import Awaitable
from typing import cast

from app.core.redis import get_redis_client
from app.modules.email_auth.router import _VERIFY_SCRIPT


async def test_otp_is_consumed_once(resources):
    redis = get_redis_client()
    key = f"test:otp:{uuid.uuid4()}"
    try:
        await cast(Awaitable[int], redis.hset(key, mapping={"digest": "expected", "attempts": 0}))
        await redis.expire(key, 600)
        assert 0 < await redis.ttl(key) <= 600
        assert await cast(Awaitable[int], redis.eval(_VERIFY_SCRIPT, 1, key, "expected")) == 1
        assert await cast(Awaitable[int], redis.eval(_VERIFY_SCRIPT, 1, key, "expected")) == 0
    finally:
        await redis.delete(key)


async def test_five_incorrect_attempts_invalidate_even_the_correct_code(resources):
    redis = get_redis_client()
    key = f"test:otp:{uuid.uuid4()}"
    try:
        await cast(Awaitable[int], redis.hset(key, mapping={"digest": "expected", "attempts": 0}))
        await redis.expire(key, 600)
        for _ in range(5):
            assert await cast(Awaitable[int], redis.eval(_VERIFY_SCRIPT, 1, key, "wrong")) == 0
        assert not await redis.exists(key)
        assert await cast(Awaitable[int], redis.eval(_VERIFY_SCRIPT, 1, key, "expected")) == 0
    finally:
        await redis.delete(key)


async def test_expired_otp_is_rejected(resources):
    redis = get_redis_client()
    key = f"test:otp:{uuid.uuid4()}"
    try:
        await cast(Awaitable[int], redis.hset(key, mapping={"digest": "expected", "attempts": 0}))
        await redis.expire(key, 0)
        assert await cast(Awaitable[int], redis.eval(_VERIFY_SCRIPT, 1, key, "expected")) == 0
    finally:
        await redis.delete(key)
