"""Dataset monitoring distinguishes discovery from observed data."""

import json
import types

import pytest
from fastapi.testclient import TestClient

from app.core.dependencies import get_current_user
from app.main import app
from app.modules.rotation import router as monitor


@pytest.fixture(autouse=True)
def clean_tables():
    """These endpoint tests do not use the database."""


def test_monitor_reports_recorded_observations_and_discovery_separately(tmp_path, monkeypatch):
    path = tmp_path / "evidence.json"
    path.write_text(json.dumps({"generated_at": "2026-11-13T00:00:00Z", "results": {
        "01": {"key": "power_daily", "status": "ACQUIRED"},
        "10": {"key": "hls_s30", "status": "DISCOVERED"},
        "11": {"key": "wrong_product", "status": "ACQUIRED"},
    }}))
    monkeypatch.setattr(monitor, "_EVIDENCE_FILE", path)
    app.dependency_overrides[get_current_user] = lambda: types.SimpleNamespace(id="test")
    try:
        response = TestClient(app).get("/api/v1/intelligence/datasets")
    finally:
        app.dependency_overrides.clear()
    rows = response.json()
    assert response.status_code == 200 and len(rows) == 30
    assert rows[0]["status"] == "ACQUIRED" and rows[0]["acquired"] == "RECORDED"
    assert rows[0]["validated"] == "UNKNOWN" and rows[0]["integrated"] == "UNKNOWN"
    assert rows[9]["status"] == "DISCOVERED" and rows[9]["acquired"] == "NOT_VERIFIED"
    assert rows[10]["status"] == "NOT_CHECKED" and rows[10]["last_updated"] is None
    assert rows[1]["status"] == "NOT_CHECKED" and rows[1]["blocker"]


def test_corrupt_evidence_never_reports_success(tmp_path, monkeypatch):
    path = tmp_path / "evidence.json"
    path.write_text("not json")
    monkeypatch.setattr(monitor, "_EVIDENCE_FILE", path)
    app.dependency_overrides[get_current_user] = lambda: types.SimpleNamespace(id="test")
    try:
        rows = TestClient(app).get("/api/v1/intelligence/datasets").json()
    finally:
        app.dependency_overrides.clear()
    assert len(rows) == 30 and all(row["status"] == "NOT_CHECKED" for row in rows)
