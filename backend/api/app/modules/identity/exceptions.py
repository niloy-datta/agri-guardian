from app.core.exceptions import ConflictError, NotFoundError


class UserNotFoundError(NotFoundError):
    error_code = "user_not_found"


class RoleNotFoundError(NotFoundError):
    error_code = "role_not_found"


class RoleAlreadyAssignedError(ConflictError):
    error_code = "role_already_assigned"
