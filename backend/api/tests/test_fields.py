"""Field CRUD against real PostGIS.

Covers the three things that are easy to get wrong and impossible to test
without a spatial database: geodesic area derived on write, topological
validation of the submitted polygon, and ownership isolation.
"""

import uuid

from httpx import AsyncClient

from tests.conftest import bowtie_polygon, square_polygon


async def _create_field(
    client: AsyncClient, headers: dict[str, str], **overrides: object
) -> dict:
    payload = {
        "name": "North plot",
        "boundary": square_polygon(),
        "country_code": "BD",
        "region": "Dhaka",
    }
    payload.update(overrides)
    response = await client.post("/api/v1/fields", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def test_create_field_derives_area_and_centroid(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)

    assert field["name"] == "North plot"
    assert field["status"] == "ACTIVE"
    assert field["version"] == 1

    # A ~0.01 degree square near latitude 23.8 is roughly 1.13 km a side.
    # The assertion is deliberately loose: it proves PostGIS computed a
    # plausible geodesic area, not that a constant was echoed back.
    area = float(field["area_sq_m"])
    assert 1.0e6 < area < 1.5e6
    assert field["area_acres"] > 0

    assert 90.40 < field["centroid"]["longitude"] < 90.41
    assert 23.80 < field["centroid"]["latitude"] < 23.81

    assert field["boundary"]["type"] == "Polygon"
    assert len(field["boundary"]["coordinates"][0]) == 5


async def test_create_field_rejects_structurally_invalid_polygon(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """An unclosed ring never reaches the database."""
    unclosed = {
        "type": "Polygon",
        "coordinates": [[[90.40, 23.80], [90.41, 23.80], [90.41, 23.81]]],
    }
    response = await client.post(
        "/api/v1/fields",
        json={"name": "Bad", "boundary": unclosed, "country_code": "BD"},
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_create_field_rejects_non_polygon_geometry(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/fields",
        json={
            "name": "Point",
            "boundary": {"type": "Point", "coordinates": [90.4, 23.8]},
            "country_code": "BD",
        },
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_create_field_rejects_self_intersecting_polygon(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """Only PostGIS can catch this one - the JSON is perfectly well-formed."""
    response = await client.post(
        "/api/v1/fields",
        json={"name": "Bowtie", "boundary": bowtie_polygon(), "country_code": "BD"},
        headers=farmer_headers,
    )
    assert response.status_code == 422
    assert response.json()["error_code"] == "invalid_field_boundary"


async def test_get_and_list_own_fields(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    created = await _create_field(client, farmer_headers)

    fetched = await client.get(f"/api/v1/fields/{created['id']}", headers=farmer_headers)
    assert fetched.status_code == 200
    assert fetched.json()["id"] == created["id"]

    listed = await client.get("/api/v1/fields", headers=farmer_headers)
    assert listed.status_code == 200
    page = listed.json()
    assert [item["id"] for item in page["items"]] == [created["id"]]
    assert page["has_more"] is False


async def test_update_field_bumps_version(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    created = await _create_field(client, farmer_headers)

    response = await client.patch(
        f"/api/v1/fields/{created['id']}",
        json={"name": "South plot", "expected_version": created["version"]},
        headers=farmer_headers,
    )
    assert response.status_code == 200
    updated = response.json()
    assert updated["name"] == "South plot"
    assert updated["version"] == created["version"] + 1


async def test_update_field_with_stale_version_conflicts(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """The offline-edit case: a client pushes an edit based on an old read."""
    created = await _create_field(client, farmer_headers)

    first = await client.patch(
        f"/api/v1/fields/{created['id']}",
        json={"name": "Renamed once", "expected_version": 1},
        headers=farmer_headers,
    )
    assert first.status_code == 200

    stale = await client.patch(
        f"/api/v1/fields/{created['id']}",
        json={"name": "Renamed from a stale copy", "expected_version": 1},
        headers=farmer_headers,
    )
    assert stale.status_code == 409
    assert stale.json()["error_code"] == "field_version_conflict"


async def test_field_of_another_farmer_is_not_readable(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    other_farmer_headers: dict[str, str],
) -> None:
    """404 rather than 403, so field ids are not probeable."""
    created = await _create_field(client, farmer_headers)

    response = await client.get(
        f"/api/v1/fields/{created['id']}", headers=other_farmer_headers
    )
    assert response.status_code == 404

    listed = await client.get("/api/v1/fields", headers=other_farmer_headers)
    assert listed.json()["items"] == []


async def test_unknown_field_returns_404(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.get(f"/api/v1/fields/{uuid.uuid4()}", headers=farmer_headers)
    assert response.status_code == 404


async def test_create_field_is_idempotent_per_key(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """A retried offline mutation must not create a second field."""
    payload = {
        "name": "Retried plot",
        "boundary": square_polygon(),
        "country_code": "BD",
    }
    headers = {**farmer_headers, "Idempotency-Key": "field-create-001"}

    first = await client.post("/api/v1/fields", json=payload, headers=headers)
    second = await client.post("/api/v1/fields", json=payload, headers=headers)

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]

    listed = await client.get("/api/v1/fields", headers=farmer_headers)
    assert len(listed.json()["items"]) == 1
