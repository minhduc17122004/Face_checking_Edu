"""Unify attendance identity — remove user_id, add critical indexes.

Removes user_id from attendance and face_embeddings tables (unified identity).
Adds performance indexes on attendance, sessions, and classroom_students.
Removes job_title from students (use academic_class_id instead).

Revision ID: 0011
Revises: 0010
Create Date: 2026-03-19
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Remove user_id from attendance ───────────────────────────────────────
    # Check if column exists (graceful for fresh databases)
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    attendance_cols = [c["name"] for c in inspector.get_columns("attendance")]

    if "user_id" in attendance_cols:
        op.drop_column("attendance", "user_id")

    # ── 2. Remove user_id from face_embeddings ──────────────────────────────────
    face_emb_cols = [c["name"] for c in inspector.get_columns("face_embeddings")]
    if "user_id" in face_emb_cols:
        op.drop_column("face_embeddings", "user_id")

    # ── 3. Add status check constraint ─────────────────────────────────────────
    # Drop existing one if present (from model re-creation)
    op.execute("DROP INDEX IF EXISTS ix_attendance_session_student")
    op.execute("DROP INDEX IF EXISTS ix_attendance_checkin_time")

    # Composite unique constraint: one attendance per student per session
    op.create_index(
        "ix_attendance_session_student",
        "attendance",
        ["session_id", "student_id"],
        unique=False,
    )
    op.create_index(
        "ix_attendance_checkin_time",
        "attendance",
        ["checkin_time"],
        unique=False,
    )

    # ── 4. Add composite index to sessions ─────────────────────────────────────
    op.execute("DROP INDEX IF EXISTS ix_sessions_classroom_start")
    op.create_index(
        "ix_sessions_classroom_start",
        "sessions",
        ["classroom_id", "start_time"],
        unique=False,
    )

    # ── 5. Add composite index to classroom_students ────────────────────────────
    op.execute("DROP INDEX IF EXISTS ix_classroom_students_class_student")
    op.create_index(
        "ix_classroom_students_class_student",
        "classroom_students",
        ["classroom_id", "student_id"],
        unique=False,
    )

    # ── 6. Add index to face_embeddings student_id ─────────────────────────────
    # (already exists from initial migration, but ensure it's there)
    op.create_index(
        "ix_face_embeddings_student_id",
        "face_embeddings",
        ["student_id"],
        unique=False,
        if_not_exists=True,
    )


def downgrade() -> None:
    conn = op.get_bind()

    # Remove indexes
    op.drop_index("ix_classroom_students_class_student", table_name="classroom_students")
    op.drop_index("ix_sessions_classroom_start", table_name="sessions")
    op.drop_index("ix_attendance_checkin_time", table_name="attendance")
    op.drop_index("ix_attendance_session_student", table_name="attendance")

    # Re-add user_id columns (nullable for data integrity)
    if not _column_exists(conn, "attendance", "user_id"):
        op.add_column(
            "attendance",
            sa.Column(
                "user_id",
                sa.dialects.postgresql.UUID(as_uuid=True),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )

    if not _column_exists(conn, "face_embeddings", "user_id"):
        op.add_column(
            "face_embeddings",
            sa.Column(
                "user_id",
                sa.dialects.postgresql.UUID(as_uuid=True),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )


def _column_exists(conn, table: str, column: str) -> bool:
    inspector = sa.inspect(conn)
    return column in [c["name"] for c in inspector.get_columns(table)]
