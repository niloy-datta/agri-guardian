"""Integration-client tests are pure unit tests (httpx.MockTransport): they
need neither PostgreSQL nor Redis, so the database-backed autouse fixture
from the parent conftest is replaced with a no-op here. Without this the
whole directory would be skipped on any machine without a database."""

import pytest


@pytest.fixture(autouse=True)
def clean_tables() -> None:
    return None
