"""Intelligence foundation

The `intelligence` schema itself is created in 001. No tables land here yet:
earth-observation scenes, indices, risk assessments and advisories
are defined with the NASA/Copernicus pipeline that produces them, so
that their columns are driven by real payloads rather than guesses.

This revision exists so the chain has a stable, already-deployed link to
attach those tables to, instead of renumbering the whole history later.

Revision ID: 004_intelligence_foundation
Revises: 003_farm
"""

from collections.abc import Sequence

revision: str = "004_intelligence_foundation"
down_revision: str | None = "003_farm"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
