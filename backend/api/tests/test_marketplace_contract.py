"""Phase 12B contract-hardening regression tests: field/crop-cycle
ownership, safe seller/buyer/listing/order summaries, future-harvest
correctness, price-sort cursor correctness, and filter validation.
"""

import uuid
from datetime import UTC, datetime, timedelta

from httpx import AsyncClient

from tests.conftest import square_polygon


async def _create_field(client: AsyncClient, headers: dict[str, str], **overrides: object) -> dict:
    payload = {"name": "North plot", "boundary": square_polygon(), "country_code": "BD"}
    payload.update(overrides)
    response = await client.post("/api/v1/fields", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


async def _create_crop_cycle(
    client: AsyncClient, field_id: str, headers: dict[str, str], **overrides: object
) -> dict:
    payload = {"crop_code": "RICE_AMAN"}
    payload.update(overrides)
    response = await client.post(
        f"/api/v1/fields/{field_id}/crop-cycles", json=payload, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()


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
    return response


# --- Task 1/2: field/crop-cycle ownership ---


async def test_seller_cannot_list_another_farmers_field(
    client: AsyncClient, farmer_headers: dict[str, str], other_farmer_headers: dict[str, str]
) -> None:
    other_field = await _create_field(client, other_farmer_headers)
    response = await _create_listing(client, farmer_headers, field_id=other_field["id"])
    assert response.status_code == 404


async def test_seller_cannot_list_another_farmers_crop_cycle(
    client: AsyncClient, farmer_headers: dict[str, str], other_farmer_headers: dict[str, str]
) -> None:
    other_field = await _create_field(client, other_farmer_headers)
    other_cycle = await _create_crop_cycle(client, other_field["id"], other_farmer_headers)
    response = await _create_listing(client, farmer_headers, crop_cycle_id=other_cycle["id"])
    assert response.status_code == 404


async def test_crop_cycle_field_mismatch_rejected(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field_a = await _create_field(client, farmer_headers, name="Field A")
    field_b = await _create_field(client, farmer_headers, name="Field B")
    cycle_on_a = await _create_crop_cycle(client, field_a["id"], farmer_headers)

    response = await _create_listing(
        client, farmer_headers, field_id=field_b["id"], crop_cycle_id=cycle_on_a["id"]
    )
    assert response.status_code == 422


async def test_own_field_and_crop_cycle_works(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    field = await _create_field(client, farmer_headers)
    cycle = await _create_crop_cycle(client, field["id"], farmer_headers)

    response = await _create_listing(
        client, farmer_headers, field_id=field["id"], crop_cycle_id=cycle["id"]
    )
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["field_id"] == field["id"]
    assert body["crop_cycle_id"] == cycle["id"]


async def test_nonexistent_field_id_rejected(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await _create_listing(client, farmer_headers, field_id=str(uuid.uuid4()))
    assert response.status_code == 404


# --- Task 3/4: safe seller/buyer summaries ---


async def test_listing_includes_safe_seller_summary(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await _create_listing(client, farmer_headers)
    body = response.json()
    assert body["seller"]["farmer_id"] == body["seller_farmer_id"]
    assert "display_name" in body["seller"]


async def test_no_seller_private_identity_leaks(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    response = await _create_listing(client, farmer_headers)
    raw = response.text.lower()
    assert "email" not in raw
    assert "auth_subject" not in raw
    assert "phone" not in raw


async def test_bid_inbox_includes_safe_buyer_summary(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = (await _create_listing(client, farmer_headers)).json()
    await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    inbox = await client.get(
        f"/api/v1/marketplace/listings/{listing['id']}/bids", headers=farmer_headers
    )
    assert inbox.status_code == 200
    item = inbox.json()["items"][0]
    assert "buyer_id" in item["buyer"]
    assert "display_name" in item["buyer"]
    assert "email" not in inbox.text.lower()


# --- Task 5/6: listing/order summaries ---


async def test_my_bids_contains_listing_summary(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = (await _create_listing(client, farmer_headers, product_name="Summary Rice")).json()
    await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    my_bids = await client.get("/api/v1/marketplace/my-bids", headers=buyer_headers)
    assert my_bids.status_code == 200
    item = next(i for i in my_bids.json()["items"] if i["listing_id"] == listing["id"])
    assert item["listing"]["product_name"] == "Summary Rice"
    assert item["listing"]["listing_kind"] == "CROP"
    assert item["listing"]["quantity_unit"] == "KG"


async def test_order_response_contains_listing_and_counterparty_summary(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = (await _create_listing(client, farmer_headers, product_name="Order Summary Rice")).json()
    bid = (
        await client.post(
            f"/api/v1/marketplace/listings/{listing['id']}/bids",
            json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
            headers=buyer_headers,
        )
    ).json()
    accept = await client.post(
        f"/api/v1/marketplace/bids/{bid['id']}/accept", headers=farmer_headers
    )
    order_id = accept.json()["order_id"]

    order = await client.get(f"/api/v1/marketplace/orders/{order_id}", headers=farmer_headers)
    body = order.json()
    assert body["listing"]["product_name"] == "Order Summary Rice"
    assert body["listing"]["listing_kind"] == "CROP"
    assert "seller_display_name" in body
    assert "buyer_display_name" in body
    assert "email" not in order.text.lower()


# --- Task 7: future-harvest correctness ---


async def test_future_harvest_past_date_is_false(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    body = (
        await _create_listing(
            client, farmer_headers, available_from="2020-01-01", harvest_date="2020-01-01"
        )
    ).json()
    assert body["is_future_harvest"] is False


async def test_future_harvest_today_is_false(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    today = datetime.now(UTC).date().isoformat()
    body = (await _create_listing(client, farmer_headers, available_from=today)).json()
    assert body["is_future_harvest"] is False


async def test_future_harvest_future_available_from_is_true(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    future = (datetime.now(UTC).date() + timedelta(days=30)).isoformat()
    body = (await _create_listing(client, farmer_headers, available_from=future)).json()
    assert body["is_future_harvest"] is True


async def test_future_harvest_future_harvest_date_without_available_from_is_true(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    future = (datetime.now(UTC).date() + timedelta(days=30)).isoformat()
    body = (await _create_listing(client, farmer_headers, harvest_date=future)).json()
    assert body["is_future_harvest"] is True


# --- Task 8: price_desc cursor correctness ---


async def test_price_desc_pagination_no_duplicate_or_skipped_rows(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = (await _create_listing(client, farmer_headers, quantity_total="1000.000")).json()
    prices = [500, 300, 300, 300, 100, 900, 700]
    for price in prices:
        response = await client.post(
            f"/api/v1/marketplace/listings/{listing['id']}/bids",
            json={"quantity": "1", "unit_price_minor": price, "currency": "BDT"},
            headers=buyer_headers,
        )
        assert response.status_code == 201, response.text

    seen_ids: list[str] = []
    cursor = None
    for _ in range(10):
        params = {"sort": "price_desc", "limit": 2}
        if cursor:
            params["cursor"] = cursor
        page = await client.get(
            f"/api/v1/marketplace/listings/{listing['id']}/bids",
            params=params,
            headers=farmer_headers,
        )
        assert page.status_code == 200
        body = page.json()
        seen_ids.extend(item["id"] for item in body["items"])
        if not body["has_more"]:
            break
        cursor = body["next_cursor"]

    assert len(seen_ids) == len(prices)
    assert len(set(seen_ids)) == len(prices)  # no duplicates, no skips


# --- Task 9: filter validation ---


async def test_invalid_listing_kind_filter_returns_422(client: AsyncClient) -> None:
    response = await client.get(
        "/api/v1/marketplace/listings", params={"listing_kind": "NOT_A_KIND"}
    )
    assert response.status_code == 422


async def test_invalid_status_filter_returns_422(client: AsyncClient) -> None:
    response = await client.get("/api/v1/marketplace/listings", params={"status": "NOT_A_STATUS"})
    assert response.status_code == 422


async def test_invalid_sort_value_returns_422(
    client: AsyncClient, farmer_headers: dict[str, str]
) -> None:
    listing = (await _create_listing(client, farmer_headers)).json()
    response = await client.get(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        params={"sort": "not_a_sort"},
        headers=farmer_headers,
    )
    assert response.status_code == 422


async def test_invalid_order_status_filter_returns_422(client: AsyncClient, farmer_headers: dict[str, str]) -> None:
    response = await client.get(
        "/api/v1/marketplace/orders", params={"status": "NOT_A_STATUS"}, headers=farmer_headers
    )
    assert response.status_code == 422
