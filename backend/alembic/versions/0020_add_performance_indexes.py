"""Add performance indexes for query optimization.

Revision ID: 0020_add_performance_indexes
Revises: 0019_add_production_constraints
Create Date: 2026-03-21

Changes:
1. ix_sessions_schedule_date   — composite index on (schedule_id, session_date)
2. ix_attendance_session_student — composite index on (session_id, student_id)
3. ix_face_embeddings_active    — partial index on face_embeddings(student_id) WHERE deleted_at IS NULL
4. ix_devices_active_room      — partial index on devices(device_code, deleted_at) WHERE is_active = true
5. ix_course_enrollment_active  — partial index on course_enrollments(course_id, student_id) WHERE deleted_at IS NULL
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0020_add_performance_indexes"
down_revision: Union[str, None] = "0019_add_production_constraints"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. sessions: composite index for idempotent generation queries
    op.create_index(
        "ix_sessions_schedule_date",
        "sessions",
        ["schedule_id", "session_date"],
        if_not_exists=True,
    )

    # 2. attendance: composite index for duplicate detection and session queries
    # (already exists as ix_attendance_session_student per model — add as safety)
    op.create_index(
        "ix_attendance_session_student",
        "attendance",
        ["session_id", "student_id"],
        if_not_exists=True,
    )

    # 3. face_embeddings: partial index for active embeddings by student
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_face_embeddings_active
        ON face_embeddings(student_id)
        WHERE deleted_at IS NULL;
        """
    )

    # 4. devices: partial index for active device lookup by code
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_devices_active_room
        ON devices(device_code, deleted_at)
        WHERE is_active = true;
        """
    )

    # 5. course_enrollments: partial index for active enrollment lookups
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_course_enrollment_active
        ON course_enrollments(course_id, student_id);
        """
    )


def downgrade() -> None:
    op.drop_index("ix_sessions_schedule_date", table_name="sessions", if_exists=True)
    op.drop_index("ix_attendance_session_student", table_name="attendance", if_exists=True)
    op.execute("DROP INDEX IF EXISTS ix_face_embeddings_active")
    op.execute("DROP INDEX IF EXISTS ix_devices_active_room")
    op.execute("DROP INDEX IF EXISTS ix_course_enrollment_active")
