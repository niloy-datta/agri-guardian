from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, ValidationAppError


class FieldNotFoundError(NotFoundError):
    error_code = "field_not_found"


class FieldAccessDeniedError(ForbiddenError):
    error_code = "field_access_denied"


class InvalidFieldBoundaryError(ValidationAppError):
    error_code = "invalid_field_boundary"


class FieldVersionConflictError(ConflictError):
    error_code = "field_version_conflict"
