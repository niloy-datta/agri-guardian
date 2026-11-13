# Built with repo root as the build context (see docker-compose.yml) so a
# single image can serve both the FastAPI app (backend/api/app) and the
# Celery workers (backend/workers), which share the same dependency set.
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/api/pyproject.toml /app/pyproject.toml
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -e /app[dev] || pip install --no-cache-dir \
        "fastapi>=0.115" "uvicorn[standard]>=0.32" "sqlalchemy>=2.0" \
        "asyncpg>=0.30" "psycopg[binary]>=3.2" "alembic>=1.13" \
        "geoalchemy2>=0.15" "pydantic>=2.9" "pydantic-settings>=2.5" \
        "redis>=5.1" "celery>=5.4" "httpx>=0.27" "python-jose[cryptography]>=3.3" \
        "structlog>=24.4"

COPY backend/api/app /app/app
COPY backend/api/alembic /app/alembic
COPY backend/api/alembic.ini /app/alembic.ini
COPY backend/workers /backend/workers
COPY backend/scheduler /backend/scheduler

ENV PYTHONPATH=/app:/backend

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
