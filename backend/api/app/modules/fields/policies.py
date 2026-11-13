"""Authorization rules for fields.

Ownership is checked against the farmer profile, not the raw user id, so
an agent or agronomist acting on a farmer's behalf can be granted access
later without changing the ownership model.
"""

import uuid

from app.modules.fields.models import Field
from app.shared.enums import RoleCode


def can_read_field(*, field: Field, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    if field.farmer_id == farmer_id:
        return True
    return bool(role_codes.intersection({RoleCode.ADMIN, RoleCode.AGRONOMIST}))


def can_write_field(*, field: Field, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    if field.farmer_id == farmer_id:
        return True
    return RoleCode.ADMIN in role_codes
