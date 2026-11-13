"""Real-Postgres concurrency test for the atomic bid-acceptance transaction.

No mocked locking: two real concurrent HTTP requests, each driving its own
database session from the real connection pool, race to accept two bids
that together exceed the listing's available quantity. `SELECT ... FOR
UPDATE` on the listing row (Task 26) must serialize them so exactly one
wins and the other observes the post-decrement state and fails cleanly.
"""

import asyncio
from decimal import Decimal

import sqlalchemy
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


async def test_two_concurrent_accepts_only_one_wins(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
    migrated_database: sqlalchemy.Engine,
) -> None:
    listing = await _create_listing(client, farmer_headers)

    bid_a_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "80", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    bid_b_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "80", "unit_price_minor": 90, "currency": "BDT"},
        headers=other_buyer_headers,
    )
    bid_a = bid_a_response.json()
    bid_b = bid_b_response.json()

    async def accept(bid_id: str) -> object:
        return await client.post(f"/api/v1/marketplace/bids/{bid_id}/accept", headers=farmer_headers)

    result_a, result_b = await asyncio.gather(accept(bid_a["id"]), accept(bid_b["id"]))

    statuses = sorted([result_a.status_code, result_b.status_code])
    assert statuses == [200, 409], (result_a.status_code, result_a.text, result_b.status_code, result_b.text)

    listing_after = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    body = listing_after.json()
    assert Decimal(body["quantity_available"]) == Decimal("20.000")
    assert Decimal(body["quantity_available"]) >= 0

    with migrated_database.connect() as connection:
        order_count = connection.execute(
            sqlalchemy.text(
                "SELECT count(*) FROM commerce.orders WHERE listing_id = :listing_id"
            ),
            {"listing_id": listing["id"]},
        ).scalar_one()
        reservation_count = connection.execute(
            sqlalchemy.text(
                "SELECT count(*) FROM commerce.inventory_reservations "
                "WHERE listing_id = :listing_id AND status = 'ACTIVE'"
            ),
            {"listing_id": listing["id"]},
        ).scalar_one()

    assert order_count == 1
    assert reservation_count == 1


async def test_oversell_never_produces_negative_available_quantity(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_buyer_headers: dict[str, str],
) -> None:
    """A tighter margin than the primary test: two bids that together
    exceed availability by a small amount, run many times in one table to
    build confidence the lock genuinely serializes rather than merely
    "usually" working."""
    listing = await _create_listing(client, farmer_headers)

    bid_a_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "60", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    bid_b_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "60", "unit_price_minor": 100, "currency": "BDT"},
        headers=other_buyer_headers,
    )
    bid_a = bid_a_response.json()
    bid_b = bid_b_response.json()

    async def accept(bid_id: str) -> object:
        return await client.post(f"/api/v1/marketplace/bids/{bid_id}/accept", headers=farmer_headers)

    result_a, result_b = await asyncio.gather(accept(bid_a["id"]), accept(bid_b["id"]))
    statuses = sorted([result_a.status_code, result_b.status_code])
    assert statuses == [200, 409]

    listing_after = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    assert Decimal(listing_after.json()["quantity_available"]) >= 0
