"""Cross-cutting HTTP middleware: request id + timing.

Kept intentionally small. Auth is a dependency (`core/security.py`), not
middleware, so unauthenticated routes (health) are unaffected.
"""

import time
import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

logger = structlog.get_logger("http")


class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self, request: Request, call_next: RequestResponseEndpoint
    ) -> Response:
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        structlog.contextvars.bind_contextvars(request_id=request_id)

        start = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            duration_ms = (time.perf_counter() - start) * 1000
            logger.info(
                "http_request",
                method=request.method,
                path=request.url.path,
                duration_ms=round(duration_ms, 2),
            )
            structlog.contextvars.clear_contextvars()

        response.headers["X-Request-ID"] = request_id
        return response
