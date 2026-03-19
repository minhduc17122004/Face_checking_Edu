"""Add academic_class_id to students.

Revision ID: 0006
Revises: 0005
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "students",
        sa.Column(
            "academic_class_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("academic_classes.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("idx_students_academic_class", "students", ["academic_class_id"])


def downgrade() -> None:
    op.drop_index("idx_students_academic_class", table_name="students")
    op.drop_column("students", "academic_class_id")
