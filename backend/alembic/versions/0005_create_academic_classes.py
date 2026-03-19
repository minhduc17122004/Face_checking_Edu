"""Create academic_classes table.

Revision ID: 0005
Revises: 0004
Create Date: 2026-03-19
"""
from typing import Sequence, Union
import uuid

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "academic_classes",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column("code", sa.String(50), unique=True, nullable=False),
        sa.Column("name", sa.String(255), nullable=True),
        sa.Column("faculty", sa.String(255), nullable=True),
        sa.Column("course_year", sa.String(10), nullable=True),
        sa.Column(
            "advisor_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("is_deleted", sa.Boolean, default=False, nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_academic_classes_code", "academic_classes", ["code"])
    op.create_index("idx_academic_classes_is_deleted", "academic_classes", ["is_deleted"])


def downgrade() -> None:
    op.drop_index("idx_academic_classes_is_deleted", table_name="academic_classes")
    op.drop_index("idx_academic_classes_code", table_name="academic_classes")
    op.drop_table("academic_classes")
