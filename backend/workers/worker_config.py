"""Celery broker/result configuration.

Read from the same `Settings` object the API uses, so a worker can never
end up pointed at a different Redis or Postgres than the service that
enqueued its work.
"""

from dataclasses import dataclass

from app.core.config import get_settings


@dataclass(frozen=True)
class WorkerConfig:
    broker_url: str
    result_backend: str
    database_url: str
    redis_url: str


def load_worker_config() -> WorkerConfig:
    settings = get_settings()
    return WorkerConfig(
        broker_url=settings.celery_broker_url,
        result_backend=settings.celery_result_backend,
        database_url=settings.database_url,
        redis_url=settings.redis_url,
    )


def celery_settings() -> dict:
    """Options applied to the Celery app.

    `task_acks_late` + `task_reject_on_worker_lost` mean a task that dies
    mid-flight is redelivered rather than silently lost - which matters for
    the outbox drain, where a lost task means an event nobody ever sees.
    """
    config = load_worker_config()
    return {
        "broker_url": config.broker_url,
        "result_backend": config.result_backend,
        "task_serializer": "json",
        "result_serializer": "json",
        "accept_content": ["json"],
        "timezone": "UTC",
        "enable_utc": True,
        "task_acks_late": True,
        "task_reject_on_worker_lost": True,
        "worker_prefetch_multiplier": 1,
        "broker_connection_retry_on_startup": True,
    }
