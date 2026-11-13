"""Listing creation, browsing, and lifecycle."""

from httpx import AsyncClient


async def _create_listing(client: AsyncClient, headers: dict[str, str], **overrides: object) -> dict:
    payload = {
        "listing_kind": "CROP",
        "product_code": "RICE_AMAN",
        "product_name": "Aman Rice",
        "quantity_total": "1200.000",
        "quantity_unit": "KG",
        "asking_price_minor": 5200,
        "currency": "BDT",
        "grade": "A",
        "delivery_mode": "BOTH",
        "country_code": "BD",
        "district": "Rajshahi",
        "attributes": {"variety": "BRRI dhan49"},
    }
    payload.update(overrides)
    response = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def test_create_crop_listing(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers)

    assert listing["listing_kind"] == "CROP"
    assert listing["status"] == "ACTIVE"
    assert listing["quantity_total"] == "1200.000"
    assert listing["quantity_available"] == "1200.000"
    assert listing["currency"] == "BDT"
    assert listing["attributes"] == {"variety": "BRRI dhan49"}
    assert "seller_farmer_id" in listing
    assert listing["version"] == 1


async def test_create_fish_listing(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(
        client,
        farmer_headers,
        listing_kind="FISH",
        product_code="TILAPIA",
        product_name="Tilapia",
        attributes={"species": "Nile Tilapia", "estimated_biomass_kg": 500},
    )
    assert listing["listing_kind"] == "FISH"
    assert listing["attributes"]["species"] == "Nile Tilapia"


async def test_future_harvest_listing_is_marked(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(
        client,
        farmer_headers,
        harvest_date="2026-11-15",
        available_from="2026-11-16",
    )
    assert listing["is_future_harvest"] is True
    assert listing["harvest_date"] == "2026-11-15"


async def test_create_listing_rejects_non_positive_quantity(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/marketplace/listings",
        json={
            "listing_kind": "CROP",
            "product_name": "Rice",
            "quantity_total": "0",
            "quantity_unit": "KG",
            "currency": "BDT",
            "delivery_mode": "PICKUP",
            "country_code": "BD",
        },
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_create_listing_rejects_negative_price(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/marketplace/listings",
        json={
            "listing_kind": "CROP",
            "product_name": "Rice",
            "quantity_total": "10",
            "quantity_unit": "KG",
            "asking_price_minor": -1,
            "currency": "BDT",
            "delivery_mode": "PICKUP",
            "country_code": "BD",
        },
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_create_listing_rejects_invalid_currency(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await client.post(
        "/api/v1/marketplace/listings",
        json={
            "listing_kind": "CROP",
            "product_name": "Rice",
            "quantity_total": "10",
            "quantity_unit": "KG",
            "currency": "BD",
            "delivery_mode": "PICKUP",
            "country_code": "BD",
        },
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_seller_id_cannot_be_client_selected(
    client: AsyncClient, farmer_headers: dict[str, str], other_farmer_headers: dict[str, str]
) -> None:
    """Even if a client somehow sends a `seller_farmer_id`, the schema has
    no such field, so it is silently ignored, not honored."""
    listing = await _create_listing(client, farmer_headers, seller_farmer_id="00000000-0000-0000-0000-000000000000")
    other_listing = await _create_listing(client, other_farmer_headers)
    assert listing["seller_farmer_id"] != other_listing["seller_farmer_id"]
    assert listing["seller_farmer_id"] != "00000000-0000-0000-0000-000000000000"


async def test_browse_returns_only_active_listings(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers, product_code="BROWSE_TEST_1")
    await client.post(f"/api/v1/marketplace/listings/{listing['id']}/close", headers=farmer_headers)

    active = await _create_listing(client, farmer_headers, product_code="BROWSE_TEST_1")

    response = await client.get(
        "/api/v1/marketplace/listings", params={"product_code": "BROWSE_TEST_1"}
    )
    assert response.status_code == 200
    ids = {item["id"] for item in response.json()["items"]}
    assert active["id"] in ids
    assert listing["id"] not in ids


async def test_browse_district_filter(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(
        client, farmer_headers, product_code="DISTRICT_TEST", district="Khulna"
    )
    response = await client.get(
        "/api/v1/marketplace/listings", params={"district": "Khulna", "product_code": "DISTRICT_TEST"}
    )
    ids = {item["id"] for item in response.json()["items"]}
    assert listing["id"] in ids


async def test_browse_product_code_filter(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers, product_code="UNIQUE_FILTER_CODE")
    response = await client.get(
        "/api/v1/marketplace/listings", params={"product_code": "UNIQUE_FILTER_CODE"}
    )
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["id"] == listing["id"]


async def test_browse_keyset_pagination(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    for _ in range(3):
        await _create_listing(client, farmer_headers, product_code="PAGE_TEST")

    first_page = await client.get(
        "/api/v1/marketplace/listings", params={"product_code": "PAGE_TEST", "limit": 2}
    )
    body = first_page.json()
    assert len(body["items"]) == 2
    assert body["has_more"] is True
    assert body["next_cursor"] is not None

    second_page = await client.get(
        "/api/v1/marketplace/listings",
        params={"product_code": "PAGE_TEST", "limit": 2, "cursor": body["next_cursor"]},
    )
    second_body = second_page.json()
    assert len(second_body["items"]) == 1
    first_ids = {item["id"] for item in body["items"]}
    second_ids = {item["id"] for item in second_body["items"]}
    assert first_ids.isdisjoint(second_ids)


async def test_close_listing(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/close", headers=farmer_headers
    )
    assert response.status_code == 200
    assert response.json()["status"] == "CLOSED"


async def test_closed_listing_rejects_new_bid(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    await client.post(f"/api/v1/marketplace/listings/{listing['id']}/close", headers=farmer_headers)

    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    assert response.status_code == 422


async def test_farmer_a_cannot_close_farmer_b_listing(
    client: AsyncClient, farmer_headers: dict[str, str], other_farmer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/close", headers=other_farmer_headers
    )
    assert response.status_code == 403


async def test_farmer_a_cannot_see_farmer_b_bid_inbox(
    client: AsyncClient, farmer_headers: dict[str, str], other_farmer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.get(
        f"/api/v1/marketplace/listings/{listing['id']}/bids", headers=other_farmer_headers
    )
    assert response.status_code == 404
