"""Data integrity: UNIQUE constraint + additional performance indexes.

Revision ID: 0013
Revises: 0012
Create Date: 2026-03-19
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0013"
down_revision: Union[str, None] = "0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. UNIQUE constraint: one attendance per student per session ──────────────
    # Check if constraint exists before adding
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_attendance_session_student'
            ) THEN
                ALTER TABLE attendance ADD CONSTRAINT uq_attendance_session_student UNIQUE (session_id, student_id);
            END IF;
        END $$;
    """)

    # ── 2. Additional attendance indexes ──────────────────────────────────────────
    op.create_index(
        "ix_attendance_created_at",
        "attendance",
        ["created_at"],
        if_not_exists=True,
    )
    # Note: ix_attendance_student_id already exists from 0011

    # ── 3. Partial index for active face embeddings ─────────────────────────────
    # Only index active embeddings for fast lookup during recognition
    op.execute("""
        CREATE INDEX ix_face_embeddings_active_student
        ON face_embeddings(student_id)
        WHERE is_active = true
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_face_embeddings_active_student")
    op.drop_index("ix_attendance_created_at", table_name="attendance")
    op.execute("ALTER TABLE attendance DROP CONSTRAINT IF EXISTS uq_attendance_session_student")
