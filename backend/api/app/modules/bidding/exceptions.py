from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationAppError


class BidNotFoundError(NotFoundError):
    error_code = "bid_not_found"


class BidNotActiveError(ValidationAppError):
    error_code = "bid_not_active"


class BidExpiredError(ValidationAppError):
    error_code = "bid_expired"


class BidAccessDeniedError(ForbiddenError):
    error_code = "bid_access_denied"


class OwnListingBidError(ValidationAppError):
    error_code = "own_listing_bid"


class CurrencyMismatchError(ValidationAppError):
    error_code = "currency_mismatch"


class InsufficientBidQuantityError(ValidationAppError):
    error_code = "insufficient_bid_quantity"
    """Raised when a bid's quantity exceeds the listing's currently
    available quantity - at bid placement time (a soft check that can go
    stale) as well as at acceptance time (the hard, lock-protected check
    that actually matters)."""


class BidVersionConflictError(ConflictError):
    error_code = "bid_version_conflict"
