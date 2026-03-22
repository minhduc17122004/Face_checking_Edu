"""Add production constraints to sessions, attendance, departments, courses.

Revision ID: 0019_add_production_constraints
Revises: 0018_extend_courses_attendance_config
Create Date: 2026-03-21

Changes:
1. sessions: UNIQUE constraint on (schedule_id, session_date)
2. sessions: CHECK constraint on status
3. departments: UNIQUE constraint on code (DB-level)
   (attendance_mode CK already added in 0018)
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0019_add_production_constraints"
down_revision: Union[str, None] = "0018_extend_courses_attendance_config"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. sessions: UNIQUE constraint (schedule_id, session_date) for idempotent generation
    op.create_index(
        "uq_sessions_schedule_date",
        "sessions",
        ["schedule_id", "session_date"],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL"),
    )

    # 2. sessions: CHECK constraint on status (belt-and-suspenders for model-level CK)
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'ck_session_status_db'
            ) THEN
                ALTER TABLE sessions
                ADD CONSTRAINT ck_session_status_db
                CHECK (status IN ('scheduled', 'active', 'closed'));
            END IF;
        END $$;
        """
    )

    # 3. departments: UNIQUE constraint on code (belt-and-suspenders for model-level unique=True)
    op.create_index(
        "uq_departments_code",
        "departments",
        ["code"],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_sessions_schedule_date", table_name="sessions")
    op.execute("ALTER TABLE sessions DROP CONSTRAINT IF EXISTS ck_session_status_db")
    op.drop_index("uq_departments_code", table_name="departments")
