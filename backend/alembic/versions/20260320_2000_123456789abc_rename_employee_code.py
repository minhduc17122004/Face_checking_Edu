"""rename employee_code to teacher_id

Revision ID: 123456789abc
Revises: 5e31f594dece
Create Date: 2026-03-20 20:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '123456789abc'
down_revision: Union[str, None] = '5e31f594dece'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Rename column
    op.alter_column('teachers', 'employee_code', new_column_name='teacher_id')
    op.drop_constraint('teachers_employee_code_key', 'teachers', type_='unique')
    op.create_unique_constraint('teachers_teacher_id_key', 'teachers', ['teacher_id'])


def downgrade() -> None:
    op.drop_constraint('teachers_teacher_id_key', 'teachers', type_='unique')
    op.create_unique_constraint('teachers_employee_code_key', 'teachers', ['employee_code'])
    # Rename column back
    op.alter_column('teachers', 'teacher_id', new_column_name='employee_code')
