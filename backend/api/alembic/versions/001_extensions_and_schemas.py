"""Extensions and schemas

Creates the Postgres extensions and the schema namespaces every later
migration depends on. Splitting the schema/extension bootstrap from the
table definitions keeps a failed table migration from leaving a database
with no PostGIS.

- postgis:   field boundaries are real geometry, not lat/lng pairs.
- pgcrypto:  supplies gen_random_uuid() for UUID primary keys.
- pg_trgm:   trigram indexes for fuzzy crop/variety/place-name lookup.

Revision ID: 001_extensions_and_schemas
Revises:
"""

from collections.abc import Sequence

from alembic import op

revision: str = "001_extensions_and_schemas"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

EXTENSIONS = ("postgis", "pgcrypto", "pg_trgm")

# One schema per bounded context. They are all created up front so the
# boundaries are visible in the database from day one, even where the
# tables land in a later phase.
SCHEMAS = (
    "identity",
    "farm",
    "intelligence",
    "commerce",
    "circular",
    "operations",
    "platform",
)


def upgrade() -> None:
    for extension in EXTENSIONS:
        op.execute(f"CREATE EXTENSION IF NOT EXISTS {extension}")

    for schema in SCHEMAS:
        op.execute(f'CREATE SCHEMA IF NOT EXISTS "{schema}"')


def downgrade() -> None:
    for schema in reversed(SCHEMAS):
        op.execute(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE')

    # Extensions are deliberately left in place: PostGIS is expensive to
    # rebuild and may be shared with objects this migration never created.
