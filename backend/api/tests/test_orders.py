"""Order creation (via bid acceptance), reads, and authorization."""

from decimal import ROUND_HALF_UP, Decimal

from httpx import AsyncClient

from app.modules.orders.service import compute_total_amount_minor


async def _create_listing(client: AsyncClient, headers: dict[str, str], **overrides: object) -> dict:
    payload = {
        "listing_kind": "CROP",
        "product_name": "Aman Rice",
        "quantity_total": "100.000",
        "quantity_unit": "KG",
        "currency": "BDT",
        "delivery_mode": "BOTH",
        "country_code": "BD",
    }
    payload.update(overrides)
    response = await client.post("/api/v1/marketplace/listings", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def _place_and_accept(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    *,
    quantity: str = "10",
    unit_price_minor: int = 100,
    listing_overrides: dict | None = None,
) -> tuple[dict, dict]:
    listing = await _create_listing(client, farmer_headers, **(listing_overrides or {}))
    bid_response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": quantity, "unit_price_minor": unit_price_minor, "currency": "BDT"},
        headers=buyer_headers,
    )
    assert bid_response.status_code == 201, bid_response.text
    bid = bid_response.json()

    accept_response = await client.post(
        f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=farmer_headers
    )
    assert accept_response.status_code == 200, accept_response.text
    return listing, accept_response.json()


async def test_order_created_on_bid_acceptance(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing, result = await _place_and_accept(client, farmer_headers, buyer_headers)

    order_response = await client.get(
        f"/api/v1/marketplace/orders/{result['order_id']}", headers=farmer_headers
    )
    assert order_response.status_code == 200
    order = order_response.json()
    assert order["listing_id"] == listing["id"]
    assert order["status"] == "CONFIRMED"
    assert order["quantity"] in ("10.000", "10")
    assert order["total_amount_minor"] == 1000  # 10 * 100


async def test_order_total_uses_round_half_up() -> None:
    # BDT: 3 units at 33 minor-units-per-unit-average with a fractional
    # quantity that forces rounding.
    total = compute_total_amount_minor(quantity=Decimal("1.005"), unit_price_minor=100)
    exact = Decimal("1.005") * Decimal(100)
    expected = int(exact.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    assert total == expected
    assert total == 101  # 100.5 rounds up to 101


async def test_listing_quantity_decrements_after_acceptance(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing, _result = await _place_and_accept(
        client, farmer_headers, buyer_headers, quantity="30", listing_overrides={"quantity_total": "100.000"}
    )
    refreshed = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    assert refreshed.json()["quantity_available"] in ("70.000", "70")
    assert refreshed.json()["status"] == "ACTIVE"


async def test_listing_marked_sold_out_when_fully_consumed(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing, _result = await _place_and_accept(
        client, farmer_headers, buyer_headers, quantity="100", listing_overrides={"quantity_total": "100.000"}
    )
    refreshed = await client.get(f"/api/v1/marketplace/listings/{listing['id']}")
    assert refreshed.json()["quantity_available"] in ("0.000", "0")
    assert refreshed.json()["status"] == "SOLD_OUT"


async def test_unrelated_user_cannot_read_order(
    client: AsyncClient,
    farmer_headers: dict[str, str],
    buyer_headers: dict[str, str],
    other_farmer_headers: dict[str, str],
) -> None:
    _listing, result = await _place_and_accept(client, farmer_headers, buyer_headers)
    response = await client.get(
        f"/api/v1/marketplace/orders/{result['order_id']}", headers=other_farmer_headers
    )
    assert response.status_code == 404


async def test_seller_and_buyer_can_both_read_their_order(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    _listing, result = await _place_and_accept(client, farmer_headers, buyer_headers)

    seller_view = await client.get(
        f"/api/v1/marketplace/orders/{result['order_id']}", headers=farmer_headers
    )
    buyer_view = await client.get(
        f"/api/v1/marketplace/orders/{result['order_id']}", headers=buyer_headers
    )
    assert seller_view.status_code == 200
    assert buyer_view.status_code == 200
    assert seller_view.json()["id"] == buyer_view.json()["id"]


async def test_list_orders_filters_by_role(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    await _place_and_accept(client, farmer_headers, buyer_headers)

    seller_orders = await client.get(
        "/api/v1/marketplace/orders", params={"role": "SELLER"}, headers=farmer_headers
    )
    buyer_orders = await client.get(
        "/api/v1/marketplace/orders", params={"role": "BUYER"}, headers=buyer_headers
    )
    assert seller_orders.status_code == 200
    assert buyer_orders.status_code == 200
    assert len(seller_orders.json()["items"]) >= 1
    assert len(buyer_orders.json()["items"]) >= 1
