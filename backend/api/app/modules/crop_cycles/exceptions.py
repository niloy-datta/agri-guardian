from app.core.exceptions import ConflictError, NotFoundError


class CropCycleNotFoundError(NotFoundError):
    error_code = "crop_cycle_not_found"


class CropCycleVersionConflictError(ConflictError):
    error_code = "crop_cycle_version_conflict"


class ActiveCropCycleExistsError(ConflictError):
    error_code = "active_crop_cycle_exists"
