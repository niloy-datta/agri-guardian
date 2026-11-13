"""Idempotency-Key coverage for the non-repeatable marketplace POSTs.

Bid acceptance is the one that matters most: a mobile client retrying a
timed-out request must never create a second order.
"""

import uuid

from httpx import AsyncClient


async def _create_listing(client: AsyncClient, headers: dict[str, str]) -> dict:
    payload = {
        "listing_kind": "CROP",
        "product_name": "Aman Rice",
        "quantity_total": "100.000",
        "quantity_unit": "KG",
        "currency": "BDT",
        "delivery_mode": "BOTH",
        "country_code": "BD",
    }
    response = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def test_retried_accept_with_same_key_creates_one_order(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    bid_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    bid = bid_response.json()

    key = str(uuid.uuid4())
    headers_with_key = {**farmer_headers, "Idempotency-Key": key}

    first = await client.post(
        f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=headers_with_key
    )
    second = await client.post(
        f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=headers_with_key
    )

    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    assert first.json()["order_id"] == second.json()["order_id"]

    listing_after = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    assert listing_after.json()["quantity_available"] in ("90.000", "90")


async def test_retried_listing_create_with_same_key_creates_one_listing(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    key = str(uuid.uuid4())
    headers_with_key = {**farmer_headers, "Idempotency-Key": key}
    payload = {
        "listing_kind": "CROP",
        "product_name": "Idempotent Rice",
        "quantity_total": "50.000",
        "quantity_unit": "KG",
        "currency": "BDT",
        "delivery_mode": "PICKUP",
        "country_code": "BD",
    }

    first = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers_with_key)
    second = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers_with_key)

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]
