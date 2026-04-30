"""add_is_spoof_to_attendance

Revision ID: add_is_spoof
Revises: add_enrollment_counts
Create Date: 2026-04-19 19:54:00.000000+00:00

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_is_spoof'
down_revision: Union[str, None] = '3da1ca04d919'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('attendance', sa.Column('is_spoof', sa.Boolean(), server_default="false", nullable=False))


def downgrade() -> None:
    op.drop_column('attendance', 'is_spoof')
