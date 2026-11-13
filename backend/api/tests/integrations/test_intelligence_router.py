"""HTTP tests for /intelligence and field rotation routes (no network, no DB).

Auth is exercised for real (missing bearer -> 401). For the authorised
cases `get_current_user` is overridden; ad-hoc rotation replaces evidence
retrieval with a SYNTHETIC bundle so nothing leaves the machine.
"""

from __future__ import annotations

import types
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from app.compute.rotation_engine import CropEvidence
from app.core.dependencies import get_current_user
from app.integrations.reference.crop_calendars import calendars_for_district
from app.main import app
from app.modules.rotation import router as rotation_router
from app.modules.rotation import service as svc

API = "/api/v1"


@pytest.fixture
def anon() -> Iterator[TestClient]:
    app.dependency_overrides.clear()
    yield TestClient(app)


@pytest.fixture
def client() -> Iterator[TestClient]:
    app.dependency_overrides[get_current_user] = lambda: types.SimpleNamespace(
        id="00000000-0000-0000-0000-000000000001", role_codes={"FARMER"}
    )
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("get", "/intelligence/datasets"),
        ("get", "/intelligence/locations/districts"),
        ("post", "/intelligence/locations/resolve"),
        ("post", "/intelligence/rotation-scenarios"),
        ("get", "/fields/00000000-0000-0000-0000-000000000001/rotation-profile"),
        ("post", "/fields/00000000-0000-0000-0000-000000000001/rotation-scenarios"),
    ],
)
def test_every_route_requires_auth(anon: TestClient, method: str, path: str) -> None:
    kwargs = {"json": {}} if method == "post" else {}
    assert anon.request(method.upper(), API + path, **kwargs).status_code == 401


def test_datasets_lists_all_thirty_without_secrets(client: TestClient) -> None:
    r = client.get(f"{API}/intelligence/datasets")
    body = r.json()
    assert r.status_code == 200 and [d["number"] for d in body] == list(range(1, 31))
    assert next(d for d in body if d["key"] == "smap_l4")["doi"] == "10.5067/T5RUATAQREF8"
    assert "token" not in r.text.lower() and "password" not in r.text.lower()


def test_districts_and_divisions(client: TestClient) -> None:
    assert len(client.get(f"{API}/intelligence/locations/divisions").json()) == 8
    districts = client.get(f"{API}/intelligence/locations/districts").json()
    assert len(districts) == 64 and all(d["bamis_region"] for d in districts)
    sylhet = client.get(f"{API}/intelligence/locations/districts", params={"division": "Sylhet"})
    assert {d["name"] for d in sylhet.json()} == {"Sylhet", "Moulvibazar", "Sunamganj", "Habiganj"}


def test_resolve_point_and_field(client: TestClient) -> None:
    r = client.post(
        f"{API}/intelligence/locations/resolve", json={"latitude": 22.7185, "longitude": 89.0705}
    )
    assert r.json()["district"] == "Satkhira" and r.json()["bamis_region"] == "Khulna"
    out = client.post(
        f"{API}/intelligence/locations/resolve-field",
        json={"ring": [[88.36, 22.57], [88.37, 22.57], [88.37, 22.58], [88.36, 22.57]]},
    )
    assert out.status_code == 422


def test_calendars_endpoint_includes_flagged_rows_with_notes(client: TestClient) -> None:
    rows = client.get(f"{API}/intelligence/calendars", params={"district": "Mymensingh"}).json()
    assert any(not r["verified"] and r["qa_note"] for r in rows)
    assert (
        client.get(f"{API}/intelligence/calendars", params={"district": "Atlantis"}).status_code
        == 404
    )


def test_adhoc_rotation_outside_bangladesh_rejected(client: TestClient) -> None:
    r = client.post(
        f"{API}/intelligence/rotation-scenarios", json={"latitude": 22.57, "longitude": 88.36}
    )
    assert r.status_code == 422


def test_adhoc_rotation_shape_with_synthetic_evidence(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    async def fake_build(_hub: object, location: object) -> svc.EvidenceBundle:
        crops = [CropEvidence(w.crop, w) for w in calendars_for_district("Sylhet")]
        item = svc.EvidenceItem(7, "BAMIS (synthetic test bundle)", "AVAILABLE", "", "", "")
        return svc.EvidenceBundle(location, [item], crops, "2026-11-13T00:00:00Z")  # type: ignore[arg-type]

    monkeypatch.setattr(rotation_router.svc, "build_evidence", fake_build)
    r = client.post(
        f"{API}/intelligence/rotation-scenarios",
        json={"latitude": 24.8949, "longitude": 91.8687, "irrigation_access": "none",
              "preferred_outcomes": ["water_saving", "income"]},
    )  # fmt: skip
    body = r.json()
    assert r.status_code == 200 and body["location"]["district"] == "Sylhet"
    assert body["unsupported_priorities"] == ["income"]
    assert all("boro_rice" not in s["crops"] for s in body["scenarios"])
    assert all(c["source"] for s in body["scenarios"] for c in s["claims"])
    assert "yield" in body["disclaimer"]
