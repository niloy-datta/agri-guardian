"""Authorization rules for identity resources."""

from app.core.permissions import require_roles
from app.modules.identity.models import User
from app.shared.enums import RoleCode

require_admin = require_roles(RoleCode.ADMIN)


def can_read_user(*, actor: User, target_user_id) -> bool:
    """A user may read their own record; admins may read anyone's."""
    return actor.id == target_user_id or RoleCode.ADMIN in actor.role_codes
