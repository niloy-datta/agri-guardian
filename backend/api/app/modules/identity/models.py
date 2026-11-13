"""Identity ORM models (schema: `identity`).

`identity.users` is a local mirror of the auth provider's user, keyed by
the provider's subject id. No password material is ever stored here -
Supabase Auth (or any OIDC provider) owns credentials; this service only
verifies the issued JWT and keeps a referential-integrity anchor so domain
tables can foreign-key to a user.
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.shared.enums import MeasurementSystem, RoleCode, values
from app.shared.types import TimestampMixin, UUIDPrimaryKeyMixin, VersionMixin


class User(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("auth_subject", name="uq_identity_users_auth_subject"),
        Index("ix_identity_users_email", "email"),
        Index("ix_identity_users_phone", "phone"),
        {"schema": "identity"},
    )

    # The `sub` claim from the auth provider. Kept separate from `id` so the
    # provider can be swapped without rewriting every domain foreign key.
    auth_subject: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    country_code: Mapped[str | None] = mapped_column(String(2), nullable=True)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="ACTIVE")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    profile: Mapped["Profile"] = relationship(
        back_populates="user", uselist=False, lazy="selectin"
    )
    user_roles: Mapped[list["UserRole"]] = relationship(
        back_populates="user", lazy="selectin", cascade="all, delete-orphan"
    )

    @property
    def roles(self) -> list["Role"]:
        return [user_role.role for user_role in self.user_roles]

    @property
    def role_codes(self) -> set[str]:
        return {user_role.role.code for user_role in self.user_roles}


class Profile(Base, UUIDPrimaryKeyMixin, TimestampMixin, VersionMixin):
    """Per-user presentation and localization settings.

    Locale, timezone and measurement system live here (not hardcoded) so
    the same core works for every country pack.
    """

    __tablename__ = "profiles"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_identity_profiles_user_id"),
        CheckConstraint(
            "measurement_system IN ('" + "','".join(values(MeasurementSystem)) + "')",
            name="ck_identity_profiles_measurement_system",
        ),
        {"schema": "identity"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="CASCADE"),
        nullable=False,
    )
    display_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    avatar_storage_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    language: Mapped[str] = mapped_column(String(10), nullable=False, default="en")
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default="UTC")
    measurement_system: Mapped[str] = mapped_column(
        String(16), nullable=False, default=MeasurementSystem.METRIC.value
    )
    preferred_currency: Mapped[str | None] = mapped_column(String(3), nullable=True)

    user: Mapped[User] = relationship(back_populates="profile")


class Role(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "roles"
    __table_args__ = (
        UniqueConstraint("code", name="uq_identity_roles_code"),
        CheckConstraint(
            "code IN ('" + "','".join(values(RoleCode)) + "')",
            name="ck_identity_roles_code",
        ),
        {"schema": "identity"},
    )

    code: Mapped[str] = mapped_column(String(32), nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)


class UserRole(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "user_roles"
    __table_args__ = (
        UniqueConstraint("user_id", "role_id", name="uq_identity_user_roles_user_role"),
        Index("ix_identity_user_roles_user_id", "user_id"),
        {"schema": "identity"},
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.users.id", ondelete="CASCADE"),
        nullable=False,
    )
    role_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True),
        ForeignKey("identity.roles.id", ondelete="RESTRICT"),
        nullable=False,
    )

    user: Mapped[User] = relationship(back_populates="user_roles")
    role: Mapped[Role] = relationship(lazy="selectin")
