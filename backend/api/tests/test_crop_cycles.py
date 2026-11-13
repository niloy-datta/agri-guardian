"""Crop cycle CRUD, ownership inheritance and the one-active-cycle rule."""

import uuid

from httpx import AsyncClient

from tests.conftest import square_polygon


async def _create_field(client: AsyncClient, headers: dict[str, str]) -> dict:
    response = await client.post(
        "/api/v1/fields",
        json={
            "name": "Cycle host",
            "boundary": square_polygon(),
            "country_code": "BD",
        },
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _create_cycle(
    client: AsyncClient, field_id: str, headers: dict[str, str], **overrides: object
) -> dict:
    payload: dict = {"crop_code": "RICE_BORO", "variety": "BRRI dhan28"}
    payload.update(overrides)
    response = await client.post(
        f"/api/v1/fields/{field_id}/crop-cycles", json=payload, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_create_and_read_crop_cycle(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)
    cycle = await _create_cycle(
        client,
        field["id"],
        farmer_headers,
        planting_date="2026-01-15",
        expected_harvest_date="2026-05-20",
        irrigation_type="FLOOD",
    )

    assert cycle["field_id"] == field["id"]
    assert cycle["crop_code"] == "RICE_BORO"
    assert cycle["status"] == "PLANNED"
    assert cycle["irrigation_type"] == "FLOOD"
    assert cycle["version"] == 1

    fetched = await client.get(
        f"/api/v1/crop-cycles/{cycle['id']}", headers=farmer_headers
    )
    assert fetched.status_code == 200
    assert fetched.json()["id"] == cycle["id"]


async def test_list_cycles_for_field(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)
    await _create_cycle(client, field["id"], farmer_headers, crop_code="RICE_AMAN")
    await _create_cycle(client, field["id"], farmer_headers, crop_code="WHEAT")

    response = await client.get(
        f"/api/v1/fields/{field['id']}/crop-cycles", headers=farmer_headers
    )
    assert response.status_code == 200
    page = response.json()
    assert len(page["items"]) == 2
    assert {item["crop_code"] for item in page["items"]} == {"RICE_AMAN", "WHEAT"}


async def test_update_cycle_bumps_version(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)
    cycle = await _create_cycle(client, field["id"], farmer_headers)

    response = await client.patch(
        f"/api/v1/crop-cycles/{cycle['id']}",
        json={
            "status": "ACTIVE",
            "current_stage": "TILLERING",
            "expected_version": cycle["version"],
        },
        headers=farmer_headers,
    )
    assert response.status_code == 200
    updated = response.json()
    assert updated["status"] == "ACTIVE"
    assert updated["current_stage"] == "TILLERING"
    assert updated["version"] == cycle["version"] + 1


async def test_update_cycle_with_stale_version_conflicts(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)
    cycle = await _create_cycle(client, field["id"], farmer_headers)

    assert (
        await client.patch(
            f"/api/v1/crop-cycles/{cycle['id']}",
            json={"variety": "First edit", "expected_version": 1},
            headers=farmer_headers,
        )
    ).status_code == 200

    stale = await client.patch(
        f"/api/v1/crop-cycles/{cycle['id']}",
        json={"variety": "Stale edit", "expected_version": 1},
        headers=farmer_headers,
    )
    assert stale.status_code == 409
    assert stale.json()["error_code"] == "crop_cycle_version_conflict"


async def test_second_active_cycle_on_a_field_is_rejected(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """A field grows one crop at a time; two ACTIVE cycles would make every
    per-cycle metric downstream ambiguous."""
    field = await _create_field(client, farmer_headers)
    await _create_cycle(client, field["id"], farmer_headers, status="ACTIVE")

    response = await client.post(
        f"/api/v1/fields/{field['id']}/crop-cycles",
        json={"crop_code": "JUTE", "status": "ACTIVE"},
        headers=farmer_headers,
    )
    assert response.status_code == 409
    assert response.json()["error_code"] == "active_crop_cycle_exists"


async def test_cycle_on_unknown_field_is_rejected(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    """The foreign key is enforced before the insert, as a 404 not a 500."""
    response = await client.post(
        f"/api/v1/fields/{uuid.uuid4()}/crop-cycles",
        json={"crop_code": "RICE_BORO"},
        headers=farmer_headers,
    )
    assert response.status_code == 404
    assert response.json()["error_code"] == "field_not_found"


async def test_cycle_on_another_farmers_field_is_rejected(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    other_farmer_headers: dict[str, str],
) -> None:
    field = await _create_field(client, farmer_headers)

    created = await client.post(
        f"/api/v1/fields/{field['id']}/crop-cycles",
        json={"crop_code": "RICE_BORO"},
        headers=other_farmer_headers,
    )
    assert created.status_code == 403

    cycle = await _create_cycle(client, field["id"], farmer_headers)
    fetched = await client.get(
        f"/api/v1/crop-cycles/{cycle['id']}", headers=other_farmer_headers
    )
    assert fetched.status_code == 404


async def test_harvest_date_before_planting_date_is_rejected(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)

    response = await client.post(
        f"/api/v1/fields/{field['id']}/crop-cycles",
        json={
            "crop_code": "RICE_BORO",
            "planting_date": "2026-05-20",
            "expected_harvest_date": "2026-01-15",
        },
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_unknown_cycle_returns_404(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.get(
        f"/api/v1/crop-cycles/{uuid.uuid4()}", headers=farmer_headers
    )
    assert response.status_code == 404
