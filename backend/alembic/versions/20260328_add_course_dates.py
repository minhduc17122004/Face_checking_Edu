"""add_course_start_end_dates

Revision ID: add_course_dates
Revises: rename_course_fields
Create Date: 2026-03-28 00:52:00.000000+00:00

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_course_dates'
down_revision: Union[str, None] = 'rename_course_fields'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('courses', sa.Column('total_sessions', sa.Integer(), nullable=True))
    op.add_column('courses', sa.Column('credits', sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column('courses', 'credits')
    op.drop_column('courses', 'total_sessions')
