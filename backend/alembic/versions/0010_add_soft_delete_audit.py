"""Add soft delete and audit fields to all remaining tables.

Adds:
- users: is_deleted, deleted_at, created_by, updated_by
- students: is_deleted, deleted_at
- classes: is_deleted, deleted_at
- schedules: is_deleted, deleted_at, updated_at

Revision ID: 0010
Revises: 0009
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── users table ────────────────────────────────────────────────────────────
    # Add nullable first, then set default, then make NOT NULL
    op.add_column(
        "users",
        sa.Column("is_deleted", sa.Boolean, nullable=True),
    )
    op.execute("UPDATE users SET is_deleted = FALSE WHERE is_deleted IS NULL")
    op.alter_column("users", "is_deleted", nullable=False, server_default=sa.text("FALSE"))
    op.add_column(
        "users",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "created_by",
            sa.dialects.postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "updated_by",
            sa.dialects.postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )
    op.create_index("idx_users_is_deleted", "users", ["is_deleted"])

    # ── students table ────────────────────────────────────────────────────────
    # Note: updated_at already exists in initial schema
    op.add_column(
        "students",
        sa.Column("is_deleted", sa.Boolean, nullable=True),
    )
    op.execute("UPDATE students SET is_deleted = FALSE WHERE is_deleted IS NULL")
    op.alter_column("students", "is_deleted", nullable=False, server_default=sa.text("FALSE"))
    op.add_column(
        "students",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_students_is_deleted", "students", ["is_deleted"])

    # ── classes table ──────────────────────────────────────────────────────────
    # Note: added updated_at as it doesn't exist in initial schema
    op.add_column(
        "classes",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )
    op.add_column(
        "classes",
        sa.Column("is_deleted", sa.Boolean, nullable=True),
    )
    op.execute("UPDATE classes SET is_deleted = FALSE WHERE is_deleted IS NULL")
    op.alter_column("classes", "is_deleted", nullable=False, server_default=sa.text("FALSE"))
    op.add_column(
        "classes",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_classes_is_deleted", "classes", ["is_deleted"])

    # ── schedules table ────────────────────────────────────────────────────────
    op.add_column(
        "schedules",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )
    op.add_column(
        "schedules",
        sa.Column("is_deleted", sa.Boolean, nullable=True),
    )
    op.execute("UPDATE schedules SET is_deleted = FALSE WHERE is_deleted IS NULL")
    op.alter_column("schedules", "is_deleted", nullable=False, server_default=sa.text("FALSE"))
    op.add_column(
        "schedules",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_schedules_is_deleted", "schedules", ["is_deleted"])


def downgrade() -> None:
    # ── schedules ───────────────────────────────────────────────────────────────
    op.drop_index("idx_schedules_is_deleted", table_name="schedules")
    op.drop_column("schedules", "deleted_at")
    op.drop_column("schedules", "is_deleted")
    op.drop_column("schedules", "updated_at")

    # ── classes ────────────────────────────────────────────────────────────────
    op.drop_index("idx_classes_is_deleted", table_name="classes")
    op.drop_column("classes", "updated_at")
    op.drop_column("classes", "deleted_at")
    op.drop_column("classes", "is_deleted")

    # ── students ───────────────────────────────────────────────────────────────
    op.drop_index("idx_students_is_deleted", table_name="students")
    op.drop_column("students", "updated_at")
    op.drop_column("students", "deleted_at")
    op.drop_column("students", "is_deleted")

    # ── users ─────────────────────────────────────────────────────────────────
    op.drop_index("idx_users_is_deleted", table_name="users")
    op.drop_column("users", "updated_at")
    op.drop_column("users", "updated_by")
    op.drop_column("users", "created_by")
    op.drop_column("users", "deleted_at")
    op.drop_column("users", "is_deleted")
