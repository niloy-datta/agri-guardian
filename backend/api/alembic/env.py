"""Alembic environment.

Two jobs:

1. Point Alembic at the same database the app uses, taken from settings
   rather than alembic.ini, and coerced to a *sync* driver (Alembic runs
   migrations synchronously; the app runs on asyncpg).
2. Expose the complete `Base.metadata` so `alembic check` / autogenerate
   can prove the hand-written migration chain still matches the ORM models.
   Every `app/modules/*/models.py` is imported automatically, so a new
   domain module is picked up without editing this file.
"""

from __future__ import annotations

import importlib
import pkgutil
from logging.config import fileConfig

from alembic import context
from geoalchemy2 import alembic_helpers
from sqlalchemy import engine_from_config, pool

from app.core.config import get_settings
from app.core.database import Base

# Schemas this application owns. Anything else in the database (public,
# PostGIS internals, extensions) is none of Alembic's business.
APP_SCHEMAS = frozenset(
    {
        "identity",
        "farm",
        "intelligence",
        "commerce",
        "circular",
        "operations",
        "platform",
    }
)

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)


def _import_all_models() -> None:
    """Imports every module's `models.py` so `Base.metadata` is complete."""
    import app.modules as modules_package

    for module_info in pkgutil.iter_modules(modules_package.__path__):
        if not module_info.ispkg:
            continue
        importlib.import_module(f"{modules_package.__name__}.{module_info.name}.models")


_import_all_models()

target_metadata = Base.metadata


def _sync_database_url() -> str:
    settings = get_settings()
    url = settings.database_url_sync or settings.database_url
    # Alembic cannot drive asyncpg; psycopg speaks the same DSN.
    return url.replace("+asyncpg", "+psycopg")


config.set_main_option("sqlalchemy.url", _sync_database_url())


def _schema_of(obj: object, type_: str) -> str | None:
    if type_ == "table":
        return getattr(obj, "schema", None)
    table = getattr(obj, "table", None)
    return getattr(table, "schema", None) if table is not None else None


def include_object(obj, name, type_, reflected, compare_to):  # noqa: ANN001, ANN201
    """Restricts comparison to this application's schemas.

    Delegates to GeoAlchemy2 first, which filters out PostGIS's own
    `spatial_ref_sys` table and the spatial indexes it manages; then drops
    anything outside `APP_SCHEMAS`, including `public` and `alembic_version`.
    """
    if not alembic_helpers.include_object(obj, name, type_, reflected, compare_to):
        return False
    return _schema_of(obj, type_) in APP_SCHEMAS


_COMMON_OPTIONS = {
    "target_metadata": target_metadata,
    "include_schemas": True,
    "include_object": include_object,
    "compare_type": True,
    # Server defaults are compared loosely by Alembic (text vs. parsed
    # expression) and produce false positives on now()/gen_random_uuid().
    "compare_server_default": False,
    # GeoAlchemy2 renders Geometry/Geography columns and their GiST indexes
    # correctly in generated scripts.
    "render_item": alembic_helpers.render_item,
    "process_revision_directives": alembic_helpers.writer,
}


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        **_COMMON_OPTIONS,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, **_COMMON_OPTIONS)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
