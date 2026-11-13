"""Circular economy foundation

The `circular` schema itself is created in 001. No tables land here yet:
waste lots and their matching are defined with the circular-economy
phase.

This revision exists so the chain has a stable, already-deployed link to
attach those tables to, instead of renumbering the whole history later.

Revision ID: 006_circular_foundation
Revises: 005_commerce_foundation
"""

from collections.abc import Sequence

revision: str = "006_circular_foundation"
down_revision: str | None = "005_commerce_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
