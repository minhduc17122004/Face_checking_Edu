"""add_enrollment_counts

Revision ID: add_enrollment_counts
Revises: add_course_dates
Create Date: 2026-03-29 01:40:00.000000+00:00

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_enrollment_counts'
down_revision: Union[str, None] = 'add_course_dates'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('course_enrollments', sa.Column('absent_count', sa.Integer(), server_default="0", nullable=False))
    op.add_column('course_enrollments', sa.Column('leave_count', sa.Integer(), server_default="0", nullable=False))
    op.add_column('course_enrollments', sa.Column('late_count', sa.Integer(), server_default="0", nullable=False))
    op.add_column('course_enrollments', sa.Column('on_time_count', sa.Integer(), server_default="0", nullable=False))


def downgrade() -> None:
    op.drop_column('course_enrollments', 'on_time_count')
    op.drop_column('course_enrollments', 'late_count')
    op.drop_column('course_enrollments', 'leave_count')
    op.drop_column('course_enrollments', 'absent_count')
