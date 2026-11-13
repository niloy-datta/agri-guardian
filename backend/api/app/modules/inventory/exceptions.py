from app.core.exceptions import ConflictError


class InsufficientInventoryError(ConflictError):
    """A 409, not a 422: the bid was valid when placed, but by the time
    this accept was processed - possibly having lost a race against
    another concurrent acceptance - the listing no longer has enough
    quantity available. See Task 27's overselling-protection test."""

    error_code = "insufficient_inventory"
