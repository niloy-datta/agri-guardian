"""Bid placement, the no-auto-winner rule, withdrawal, and authorization."""

import sqlalchemy
from httpx import AsyncClient


async def _create_listing(client: AsyncClient, headers: dict[str, str], **overrides: object) -> dict:
    payload = {
        "listing_kind": "CROP",
        "product_code": "RICE_AMAN",
        "product_name": "Aman Rice",
        "quantity_total": "100.000",
        "quantity_unit": "KG",
        "asking_price_minor": 5200,
        "currency": "BDT",
        "delivery_mode": "BOTH",
        "country_code": "BD",
        "district": "Rajshahi",
    }
    payload.update(overrides)
    response = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def _place_bid(
    client: AsyncClient, listing_id: str, headers: dict[str, str], **overrides: object
) -> dict:
    payload = {"quantity": "10", "unit_price_minor": 100, "currency": "BDT"}
    payload.update(overrides)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing_id}/bids", json=payload, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()


async def test_place_bid(client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(client, listing["id"], buyer_headers)
    assert bid["status"] == "ACTIVE"
    assert bid["quantity"] == "10.000" or bid["quantity"] == "10"


async def test_multiple_buyers_can_bid_on_same_listing(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid_a = await _place_bid(client, listing["id"], buyer_headers, unit_price_minor=100)
    bid_b = await _place_bid(client, listing["id"], other_buyer_headers, unit_price_minor=150)
    assert bid_a["id"] != bid_b["id"]
    assert bid_a["status"] == "ACTIVE"
    assert bid_b["status"] == "ACTIVE"


async def test_highest_bid_never_auto_accepted(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
) -> None:
    listing = await _create_listing(client, farmer_headers)
    await _place_bid(client, listing["id"], buyer_headers, unit_price_minor=100)
    high_bid = await _place_bid(client, listing["id"], other_buyer_headers, unit_price_minor=999)

    # The listing must still be ACTIVE and the high bid must still be
    # merely ACTIVE - nothing auto-accepts it.
    listing_after = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    assert listing_after.json()["status"] == "ACTIVE"

    inbox = await client.get(
        f"/api/v1/marketplace/listings/{listing['id']}/bids", headers=farmer_headers
    )
    statuses = {bid["id"]: bid["status"] for bid in inbox.json()["items"]}
    assert statuses[high_bid["id"]] == "ACTIVE"


async def test_seller_can_manually_accept_lower_bid(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
) -> None:
    listing = await _create_listing(client, farmer_headers)
    low_bid = await _place_bid(client, listing["id"], buyer_headers, unit_price_minor=100)
    await _place_bid(client, listing["id"], other_buyer_headers, unit_price_minor=999)

    response = await client.post(
        f"/api/v1/marketplace/bids/{low_bid['id']}/accept", headers=farmer_headers
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["bid"]["status"] == "ACCEPTED"
    assert "order_id" in body


async def test_withdraw_bid(client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(client, listing["id"], buyer_headers)
    response = await client.post(f"/api/v1/marketplace/bids/{bid['id']}/withdraw", headers=buyer_headers)
    assert response.status_code == 200
    assert response.json()["status"] == "WITHDRAWN"


async def test_cannot_withdraw_accepted_bid(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(client, listing["id"], buyer_headers)
    await client.post(f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=farmer_headers)

    response = await client.post(f"/api/v1/marketplace/bids/{bid['id']}/withdraw", headers=buyer_headers)
    assert response.status_code == 422


async def test_currency_mismatch_rejected(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers, currency="BDT")
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "USD"},
        headers=buyer_headers,
    )
    assert response.status_code == 422


async def test_bid_quantity_exceeding_available_rejected(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers, quantity_total="10.000")
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "999", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    assert response.status_code == 422


async def test_expired_bid_cannot_be_accepted(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    migrated_database: sqlalchemy.Engine,
) -> None:
    """A valid (future-expiring) bid at placement time can still expire
    before the seller acts on it - placing an already-expired bid is a
    separate, already-covered rejection (see the test below)."""
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(
        client, listing["id"], buyer_headers, expires_at="2099-01-01T00:00:00+00:00"
    )

    with migrated_database.begin() as connection:
        connection.execute(
            sqlalchemy.text(
                "UPDATE commerce.bids SET expires_at = '2020-01-01T00:00:00+00:00' WHERE id = :id"
            ),
            {"id": bid["id"]},
        )

    response = await client.post(f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=farmer_headers)
    assert response.status_code == 422


async def test_bid_creation_rejects_already_expired_timestamp(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={
            "quantity": "10",
            "unit_price_minor": 100,
            "currency": "BDT",
            "expires_at": "2020-01-01T00:00:00+00:00",
        },
        headers=buyer_headers,
    )
    assert response.status_code == 422


# --- Authorization (Task 38) ---


async def test_buyer_cannot_bid_own_listing(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_buyer_cannot_accept_bid(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(client, listing["id"], buyer_headers)
    response = await client.post(f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=buyer_headers)
    assert response.status_code == 403


async def test_buyer_cannot_withdraw_another_buyers_bid(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid = await _place_bid(client, listing["id"], buyer_headers)
    response = await client.post(
        f"/api/v1/marketplace/bids/{bid['id']}/withdraw", headers=other_buyer_headers
    )
    assert response.status_code == 403
