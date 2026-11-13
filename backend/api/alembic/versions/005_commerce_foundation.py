"""Commerce foundation

The `commerce` schema itself is created in 001. No tables land here yet:
listings, bids and orders are defined with the marketplace phase, so
the money and settlement columns are modelled against real flows.

This revision exists so the chain has a stable, already-deployed link to
attach those tables to, instead of renumbering the whole history later.

Revision ID: 005_commerce_foundation
Revises: 004_intelligence_foundation
"""

from collections.abc import Sequence

revision: str = "005_commerce_foundation"
down_revision: str | None = "004_intelligence_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
