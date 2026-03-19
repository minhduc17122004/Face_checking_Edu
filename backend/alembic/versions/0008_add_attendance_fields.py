"""Add sync_time, user_id to attendance and soft delete fields.

Revision ID: 0008
Revises: 0007
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add sync_time for server-side timestamp (offline support)
    op.add_column(
        "attendance",
        sa.Column(
            "sync_time",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=True,
        ),
    )

    # Add user_id for gradual migration from student_id to user_id
    op.add_column(
        "attendance",
        sa.Column(
            "user_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("idx_attendance_user", "attendance", ["user_id"])

    # Add soft delete fields
    op.add_column(
        "attendance",
        sa.Column("is_deleted", sa.Boolean, default=False, nullable=False),
    )
    op.add_column(
        "attendance",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_attendance_is_deleted", "attendance", ["is_deleted"])

    # Add updated_at to sessions (for tracking changes)
    op.add_column(
        "sessions",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    # Add soft delete fields to sessions
    op.add_column(
        "sessions",
        sa.Column("is_deleted", sa.Boolean, default=False, nullable=False),
    )
    op.add_column(
        "sessions",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_sessions_is_deleted", "sessions", ["is_deleted"])

    # Copy checkin_time to sync_time for existing records
    op.execute("UPDATE attendance SET sync_time = checkin_time WHERE sync_time IS NULL")


def downgrade() -> None:
    # Drop sessions soft delete first
    op.drop_index("idx_sessions_is_deleted", table_name="sessions")
    op.drop_column("sessions", "deleted_at")
    op.drop_column("sessions", "is_deleted")
    op.drop_column("sessions", "updated_at")

    # Drop attendance fields
    op.drop_index("idx_attendance_is_deleted", table_name="attendance")
    op.drop_column("attendance", "deleted_at")
    op.drop_column("attendance", "is_deleted")
    op.drop_index("idx_attendance_user", table_name="attendance")
    op.drop_column("attendance", "user_id")
    op.drop_column("attendance", "sync_time")
