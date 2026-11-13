"""Test fixtures.

These are integration tests against a real PostgreSQL/PostGIS and a real
Redis. That is deliberate: the field module's correctness *is* PostGIS
behaviour - geodesic area, centroid derivation, `ST_IsValid` rejecting a
self-intersecting polygon, GiST indexes. A SQLite stand-in with a fake
geometry type would pass while the production code path was broken, so it
would be worse than no test at all.

If no database is reachable the suite skips with a clear message rather
than silently degrading; CI (.github/workflows/backend_ci.yml) always
provides both services, so nothing is skipped there.
"""

from __future__ import annotations

import os
import pathlib
import uuid
from collections.abc import AsyncIterator, Iterator
from datetime import UTC, datetime, timedelta

# The environment must be set before anything imports `app.core.config`,
# whose Settings object is read once and cached. Assigned (not defaulted)
# so an ambient DATABASE_URL can never point the suite at a real database.
BACKEND_API_ROOT = pathlib.Path(__file__).resolve().parents[1]

DEFAULT_ASYNC_DSN = (
    "postgresql+asyncpg://agri_guardian:agri_guardian@localhost:5432/agri_guardian_test"
)
DEFAULT_SYNC_DSN = (
    "postgresql+psycopg://agri_guardian:agri_guardian@localhost:5432/agri_guardian_test"
)

TEST_JWT_SECRET = "test-jwt-secret-not-used-anywhere-else"

os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL", DEFAULT_ASYNC_DSN)
os.environ["DATABASE_URL_SYNC"] = os.environ.get(
    "TEST_DATABASE_URL_SYNC", DEFAULT_SYNC_DSN
)
os.environ["REDIS_URL"] = os.environ.get("TEST_REDIS_URL", "redis://localhost:6379/15")
os.environ["SUPABASE_JWT_SECRET"] = TEST_JWT_SECRET
os.environ["SUPABASE_JWT_AUDIENCE"] = "authenticated"
os.environ["AUTH_PROVIDER"] = "supabase"
os.environ["APP_ENV"] = "test"

import pytest  # noqa: E402
import sqlalchemy  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from jose import jwt  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.database import dispose_engine, init_engine  # noqa: E402
from app.core.redis import dispose_redis, get_redis_client, init_redis  # noqa: E402
from app.main import create_app  # noqa: E402

get_settings.cache_clear()

APP_SCHEMAS = (
    "identity",
    "farm",
    "intelligence",
    "commerce",
    "circular",
    "operations",
    "platform",
)

# CASCADE resolves the order; identity.roles is excluded because it holds
# reference data seeded by migration 002, not test state.
TRUNCATE_TABLES = (
    "platform.idempotency_keys",
    "platform.audit_logs",
    "platform.outbox_events",
    "commerce.order_events",
    "commerce.inventory_reservations",
    "commerce.orders",
    "commerce.bids",
    "commerce.listings",
    "commerce.buyer_profiles",
    "farm.crop_cycles",
    "farm.fields",
    "farm.farmer_profiles",
    "identity.user_roles",
    "identity.profiles",
    "identity.users",
)


def _sync_dsn() -> str:
    return os.environ["DATABASE_URL_SYNC"]


@pytest.fixture(scope="session")
def sync_engine() -> Iterator[sqlalchemy.Engine]:
    # A short connect timeout so "no database here" is a fast skip rather
    # than a test run that appears to hang.
    engine = sqlalchemy.create_engine(
        _sync_dsn(),
        poolclass=sqlalchemy.pool.NullPool,
        connect_args={"connect_timeout": 5},
    )
    try:
        with engine.connect() as connection:
            connection.execute(sqlalchemy.text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - reported as a skip, not a failure
        pytest.skip(
            f"PostgreSQL/PostGIS is not reachable at {_sync_dsn()}: "
            f"{exc.__class__.__name__}. These are integration tests; start the "
            "database (docker compose up postgres) or set TEST_DATABASE_URL_SYNC."
        )
    yield engine
    engine.dispose()


@pytest.fixture(scope="session")
def migrated_database(sync_engine: sqlalchemy.Engine) -> sqlalchemy.Engine:
    """Drops every application schema, then runs the chain from scratch.

    This is what makes `test_migrations.py` meaningful: the suite always
    runs against a database built by `alembic upgrade head`, never by
    `metadata.create_all()`, so a migration that diverges from the models
    breaks the tests instead of hiding behind them.
    """
    with sync_engine.begin() as connection:
        for schema in APP_SCHEMAS:
            connection.execute(sqlalchemy.text(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE'))
        connection.execute(sqlalchemy.text("DROP TABLE IF EXISTS public.alembic_version"))

    config = Config(str(BACKEND_API_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_API_ROOT / "alembic"))
    command.upgrade(config, "head")
    return sync_engine


@pytest.fixture(autouse=True)
def clean_tables(migrated_database: sqlalchemy.Engine) -> None:
    with migrated_database.begin() as connection:
        connection.execute(
            sqlalchemy.text(
                f"TRUNCATE TABLE {', '.join(TRUNCATE_TABLES)} RESTART IDENTITY CASCADE"
            )
        )


@pytest.fixture
async def resources(migrated_database: sqlalchemy.Engine) -> AsyncIterator[None]:
    """Initialises the engine/Redis singletons the app's lifespan owns.

    The tests drive the ASGI app through a transport that does not run
    lifespan events, so startup is performed explicitly here.
    """
    settings = get_settings()
    init_engine(settings.database_url)
    init_redis(settings.redis_url)
    try:
        await get_redis_client().ping()
    except Exception as exc:  # noqa: BLE001 - reported as a skip, not a failure
        await dispose_redis()
        await dispose_engine()
        pytest.skip(
            f"Redis is not reachable at {settings.redis_url}: "
            f"{exc.__class__.__name__}. Start it (docker compose up redis) or set "
            "TEST_REDIS_URL."
        )
    try:
        yield
    finally:
        await dispose_redis()
        await dispose_engine()


@pytest.fixture
async def client(resources: None) -> AsyncIterator[AsyncClient]:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as http:
        yield http


@pytest.fixture
async def offline_client() -> AsyncIterator[AsyncClient]:
    """A client whose app has no database or Redis initialised.

    Used to prove the readiness probe reports the real state instead of a
    hardcoded "healthy".
    """
    await dispose_redis()
    await dispose_engine()
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as http:
        yield http


def make_token(auth_subject: str, *, email: str | None = None) -> str:
    """Mints a token the real `app.core.security` verifier accepts.

    Tests authenticate through the production dependency chain rather than
    overriding `get_current_user`, so token handling and first-sight user
    provisioning are exercised too.
    """
    now = datetime.now(UTC)
    return jwt.encode(
        {
            "sub": auth_subject,
            "email": email or f"{auth_subject}@example.test",
            "aud": "authenticated",
            "iat": int(now.timestamp()),
            "exp": int((now + timedelta(hours=1)).timestamp()),
        },
        TEST_JWT_SECRET,
        algorithm="HS256",
    )


def auth_headers(auth_subject: str | None = None) -> dict[str, str]:
    subject = auth_subject or f"test-user-{uuid.uuid4()}"
    return {"Authorization": f"Bearer {make_token(subject)}"}


@pytest.fixture
def farmer_headers() -> dict[str, str]:
    return auth_headers("farmer-primary")


@pytest.fixture
def other_farmer_headers() -> dict[str, str]:
    return auth_headers("farmer-other")


@pytest.fixture
def buyer_headers() -> dict[str, str]:
    return auth_headers("buyer-primary")


@pytest.fixture
def other_buyer_headers() -> dict[str, str]:
    return auth_headers("buyer-other")


def square_polygon(
    *, west: float = 90.40, south: float = 23.80, size: float = 0.01
) -> dict:
    """A small, valid, closed square near Dhaka - roughly 1.1 km a side."""
    east, north = west + size, south + size
    return {
        "type": "Polygon",
        "coordinates": [
            [[west, south], [east, south], [east, north], [west, north], [west, south]]
        ],
    }


def bowtie_polygon() -> dict:
    """A closed ring that crosses itself.

    Structurally well-formed, so only PostGIS `ST_IsValid` can reject it.
    """
    return {
        "type": "Polygon",
        "coordinates": [
            [
                [90.40, 23.80],
                [90.41, 23.81],
                [90.41, 23.80],
                [90.40, 23.81],
                [90.40, 23.80],
            ]
        ],
    }
