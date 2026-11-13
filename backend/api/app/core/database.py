"""Async SQLAlchemy engine/session setup.

Postgres is the single source of truth for every domain module. Every ORM
model in `app/modules/**/models.py` shares the one `Base` declared here so
Alembic (`app/../alembic/env.py`) can autogenerate against the full schema.
"""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """Shared declarative base for every module's ORM models."""


_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def init_engine(database_url: str, *, echo: bool = False) -> AsyncEngine:
    global _engine, _session_factory
    _engine = create_async_engine(database_url, echo=echo, pool_pre_ping=True)
    _session_factory = async_sessionmaker(
        bind=_engine, expire_on_commit=False, autoflush=False
    )
    return _engine


async def dispose_engine() -> None:
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _session_factory = None


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    if _session_factory is None:
        raise RuntimeError(
            "Database engine is not initialized. Call init_engine() during app startup."
        )
    return _session_factory


@asynccontextmanager
async def session_scope() -> AsyncGenerator[AsyncSession, None]:
    """Explicit transactional scope for use outside of request handlers
    (workers, scripts, tests)."""
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency yielding a request-scoped session.

    Commits on clean exit, rolls back on any exception, and always closes.
    Handlers should not call session.commit() themselves.
    """
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def ping_database() -> bool:
    """Used by the readiness probe. Returns False instead of raising so the
    caller can build a structured response."""
    from sqlalchemy import text

    if _engine is None:
        return False
    try:
        async with _engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
