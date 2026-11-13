from app.core.exceptions import NotFoundError


class OrderNotFoundError(NotFoundError):
    error_code = "order_not_found"
