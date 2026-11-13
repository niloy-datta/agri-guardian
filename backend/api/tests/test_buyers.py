"""Buyer profile auto-provisioning.

There is no direct buyer-profile endpoint in this phase - a profile is
created the first time a user places a bid (`BuyerService.
ensure_profile_for_user`, mirroring `FarmerService`'s same pattern), never
requiring admin approval.
"""

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


async def test_buyer_profile_created_on_first_bid(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    assert response.status_code == 201
    assert response.json()["buyer_id"] is not None


async def test_same_buyer_reuses_one_profile_across_bids(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    listing_a = await _create_listing(client, farmer_headers)
    listing_b = await _create_listing(client, farmer_headers)

    bid_a = await client.post(
        f"/api/v1/marketplace/listings/{listing_a['id']}/bids",
        json={"quantity": "5", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    bid_b = await client.post(
        f"/api/v1/marketplace/listings/{listing_b['id']}/bids",
        json={"quantity": "5", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )

    assert bid_a.json()["buyer_id"] == bid_b.json()["buyer_id"]


async def test_individual_buyer_with_no_business_name_works(
    client: AsyncClient, farmer_headers: dict[str, str], buyer_headers: dict[str, str]
) -> None:
    """A buyer profile requires no business/company details - an
    individual buyer must be able to bid immediately."""
    listing = await _create_listing(client, farmer_headers)
    response = await client.post(
        f"/api/v1/marketplace/listings/{listing['id']}/bids",
        json={"quantity": "10", "unit_price_minor": 100, "currency": "BDT"},
        headers=buyer_headers,
    )
    assert response.status_code == 201
