from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationAppError


class ListingNotFoundError(NotFoundError):
    error_code = "listing_not_found"


class ListingNotActiveError(ValidationAppError):
    error_code = "listing_not_active"


class ListingAccessDeniedError(ForbiddenError):
    error_code = "listing_access_denied"


class ListingAlreadyClosedError(ConflictError):
    error_code = "listing_already_closed"


class ListingFieldNotFoundError(NotFoundError):
    """A `field_id` was supplied that either does not exist or does not
    belong to the authenticated seller - 404 either way, so another
    farmer's field id is not distinguishable from a nonexistent one."""

    error_code = "listing_field_not_found"


class ListingCropCycleNotFoundError(NotFoundError):
    error_code = "listing_crop_cycle_not_found"


class ListingCropCycleFieldMismatchError(ValidationAppError):
    error_code = "listing_crop_cycle_field_mismatch"
