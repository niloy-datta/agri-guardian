#!/usr/bin/env sh
# Blocks until Postgres accepts connections, using the same DATABASE_URL_SYNC
# the API/Alembic use. Avoids a hard dependency on pg_isready in the app image.
set -eu

python - <<'PYEOF'
import os
import sys
import time

import sqlalchemy

url = os.environ.get("DATABASE_URL_SYNC") or os.environ.get("DATABASE_URL", "")
if not url:
    print("[wait-for-db] DATABASE_URL_SYNC/DATABASE_URL not set", file=sys.stderr)
    sys.exit(1)

# Alembic/psycopg need a sync driver even if DATABASE_URL is asyncpg-based.
url = url.replace("+asyncpg", "+psycopg")

engine = sqlalchemy.create_engine(url)
deadline = time.time() + 60

while True:
    try:
        with engine.connect() as conn:
            conn.execute(sqlalchemy.text("SELECT 1"))
        print("[wait-for-db] database is ready")
        break
    except Exception as exc:  # noqa: BLE001 - best-effort readiness poll
        if time.time() > deadline:
            print(f"[wait-for-db] gave up waiting for database: {exc}", file=sys.stderr)
            sys.exit(1)
        print(f"[wait-for-db] waiting for database... ({exc.__class__.__name__})")
        time.sleep(2)
PYEOF
