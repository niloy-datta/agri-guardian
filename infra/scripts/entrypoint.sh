#!/usr/bin/env sh
# Waits for Postgres, applies Alembic migrations, then starts the API.
# Used as the `api` service command in docker-compose.yml.
set -eu

cd /app

"$(dirname "$0")/wait-for-db.sh"

echo "[entrypoint] running alembic migrations..."
alembic upgrade head

echo "[entrypoint] starting uvicorn..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
