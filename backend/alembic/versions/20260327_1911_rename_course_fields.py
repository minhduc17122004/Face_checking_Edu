"""rename_course_attendance_fields

Revision ID: rename_course_fields
Revises: 7157c5c2ef6c
Create Date: 2026-03-27 19:11:00.000000+00:00

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'rename_course_fields'
down_revision: Union[str, None] = '7157c5c2ef6c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Rename columns
    op.alter_column('courses', 'attendance_before_minutes', new_column_name='custom_window_start_minutes')
    op.alter_column('courses', 'attendance_after_minutes', new_column_name='custom_window_end_minutes')
    
    # 2. Update logic: current end_minutes reflects OLD duration.
    # We want absolute end offset: new_end = start + old_duration
    op.execute("UPDATE courses SET custom_window_end_minutes = custom_window_start_minutes + custom_window_end_minutes")


def downgrade() -> None:
    # 1. Revert logic: duration = end - start
    op.execute("UPDATE courses SET custom_window_end_minutes = custom_window_end_minutes - custom_window_start_minutes")
    
    # 2. Rename back
    op.alter_column('courses', 'custom_window_start_minutes', new_column_name='attendance_before_minutes')
    op.alter_column('courses', 'custom_window_end_minutes', new_column_name='attendance_after_minutes')
