"""Authorization for crop cycles.

A crop cycle inherits its owner from its field, so access is always
decided by the field policy rather than duplicated here.
"""

import uuid

from app.modules.fields.models import Field
from app.modules.fields.policies import can_read_field, can_write_field


def can_read_cycle(*, field: Field, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    return can_read_field(field=field, farmer_id=farmer_id, role_codes=role_codes)


def can_write_cycle(*, field: Field, farmer_id: uuid.UUID, role_codes: set[str]) -> bool:
    return can_write_field(field=field, farmer_id=farmer_id, role_codes=role_codes)
