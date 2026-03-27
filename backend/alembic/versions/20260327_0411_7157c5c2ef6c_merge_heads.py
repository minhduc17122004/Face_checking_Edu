"""merge_heads

Revision ID: 7157c5c2ef6c
Revises: 0031_remove_timezone_from_time_slots, 20260325_att_cfg_mode_room
Create Date: 2026-03-27 04:11:10.134477+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7157c5c2ef6c'
down_revision: Union[str, None] = ('0031_remove_timezone_from_time_slots', '20260325_att_cfg_mode_room')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
