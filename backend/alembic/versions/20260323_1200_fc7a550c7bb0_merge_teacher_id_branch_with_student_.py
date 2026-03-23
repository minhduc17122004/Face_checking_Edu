"""merge teacher_id branch with student_groups branch

Revision ID: fc7a550c7bb0
Revises: c3385166bfd9, 0028_add_teacher_id_to_courses
Create Date: 2026-03-23 12:00:46.985486+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fc7a550c7bb0'
down_revision: Union[str, None] = ('c3385166bfd9', '0028_add_teacher_id_to_courses')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
