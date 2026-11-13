"""Health and readiness response contracts.

Deliberately separate shapes: liveness answers "is this process running",
readiness answers "can this process actually serve traffic". Collapsing
them into one payload is what produces orchestrators that keep routing to
an instance whose database is gone.
"""

from pydantic import BaseModel


class DependencyStatus(BaseModel):
    """Result of one real dependency probe."""

    name: str
    healthy: bool
    detail: str | None = None


class HealthResponse(BaseModel):
    status: str
    app: str
    environment: str
    version: str


class ReadinessResponse(BaseModel):
    ready: bool
    dependencies: list[DependencyStatus]
