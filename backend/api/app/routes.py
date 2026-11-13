"""Central API router.

Every module router is attached here and nowhere else, so the full public
surface of the service is readable in one file. `app.main` mounts this
under the configured `/api/v1` prefix; module routers therefore declare
only their own path segment, never the version.
"""

from fastapi import APIRouter

from app.modules.advisory.router import router as advisory_router
from app.modules.bidding.router import router as bidding_router
from app.modules.crop_cycles.router import field_crop_cycles_router
from app.modules.crop_cycles.router import router as crop_cycles_router
from app.modules.email_auth.router import router as email_auth_router
from app.modules.fields.router import router as fields_router
from app.modules.health.router import router as health_router
from app.modules.identity.router import router as identity_router
from app.modules.marketplace.router import router as marketplace_router
from app.modules.orders.router import router as orders_router

api_router = APIRouter()

# Health first: it is the only unauthenticated router and the one probes hit.
api_router.include_router(health_router)
api_router.include_router(email_auth_router)
api_router.include_router(identity_router)
api_router.include_router(fields_router)
# Crop cycles are addressed two ways: nested under their field for
# create/list, and by their own id for read/update.
api_router.include_router(field_crop_cycles_router)
api_router.include_router(crop_cycles_router)
api_router.include_router(advisory_router)
# Listings, bids and orders all share the /marketplace namespace; kept as
# three routers (one per module) rather than one to match the
# repository/service split each module already has.
api_router.include_router(marketplace_router)
api_router.include_router(bidding_router)
api_router.include_router(orders_router)
