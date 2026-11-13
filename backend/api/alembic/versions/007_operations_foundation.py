"""Operations foundation

The `operations` schema itself is created in 001. No tables land here yet:
missions, rescue jobs and agent dispatch are defined with the field
operations phase.

This revision exists so the chain has a stable, already-deployed link to
attach those tables to, instead of renumbering the whole history later.

Revision ID: 007_operations_foundation
Revises: 006_circular_foundation
"""

from collections.abc import Sequence

revision: str = "007_operations_foundation"
down_revision: str | None = "006_circular_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
