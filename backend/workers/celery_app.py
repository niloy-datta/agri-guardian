"""Celery application.

Entry point for `celery -A workers.celery_app:celery_app worker`.

The async SQLAlchemy engine and the Redis client are created per worker
*process* (not per task and not at import time): forking a process that
already holds a connection pool hands the same sockets to several
children, which corrupts them.
"""

from celery import Celery
from celery.signals import worker_process_init, worker_process_shutdown

from app.core.database import dispose_engine, init_engine
from app.core.logging import configure_logging, get_logger
from app.core.redis import dispose_redis, init_redis
from workers.worker_config import celery_settings, load_worker_config

logger = get_logger("worker")

celery_app = Celery("agri_guardian")
celery_app.conf.update(celery_settings())

# Only modules with real tasks are listed. Task modules for the earth
# observation, risk, vision, marketplace, circular and notification
# domains land with those phases.
celery_app.autodiscover_tasks(["workers.events"], force=True)


@worker_process_init.connect
def _init_worker_process(**_kwargs: object) -> None:
    config = load_worker_config()
    configure_logging(debug=False)
    init_engine(config.database_url)
    init_redis(config.redis_url)
    logger.info("worker_process_ready")


@worker_process_shutdown.connect
def _shutdown_worker_process(**_kwargs: object) -> None:
    import asyncio

    async def _close() -> None:
        await dispose_redis()
        await dispose_engine()

    asyncio.run(_close())
    logger.info("worker_process_closed")
