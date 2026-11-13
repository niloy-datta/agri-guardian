"""FastAPI application factory.

Import target for `uvicorn app.main:app` and for the test suite. The module
does no I/O at import time - connections are opened by the lifespan handler
in `app.lifecycle`, so importing the app (e.g. to inspect the OpenAPI
schema) never requires a database.
"""

from fastapi import FastAPI

from app import __version__
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.core.middleware import RequestContextMiddleware
from app.lifecycle import lifespan
from app.routes import api_router


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(debug=settings.app_debug)

    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        lifespan=lifespan,
        # Interactive docs are useful locally and harmless behind an
        # authenticated gateway; they are disabled outside local/dev.
        docs_url="/docs" if settings.app_debug else None,
        redoc_url="/redoc" if settings.app_debug else None,
        openapi_url="/openapi.json" if settings.app_debug else None,
    )

    app.add_middleware(RequestContextMiddleware)
    register_exception_handlers(app)
    app.include_router(api_router, prefix=settings.api_v1_prefix)

    return app


app = create_app()
