"""Extend courses with attendance config fields.

Revision ID: 0018_extend_courses_attendance_config
Revises: 0017_refactor_teachers_department
Create Date: 2026-03-21

Changes:
1. Add attendance_mode (fixed/flexible/custom) to courses
2. Add attendance_before_minutes to courses
3. Add attendance_after_minutes to courses
4. Add department_id (optional FK) to courses
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0018_extend_courses_attendance_config"
down_revision: Union[str, None] = "0017_refactor_teachers_department"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    return f"""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = '{table}' AND column_name = '{column}'
    """


def upgrade() -> None:
    # 1. Add attendance_mode
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("courses", "attendance_mode") + """) THEN
                ALTER TABLE courses
                ADD COLUMN attendance_mode VARCHAR(20) NOT NULL DEFAULT 'fixed';
            END IF;
        END $$;
    """)

    # 2. Add attendance_before_minutes
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("courses", "attendance_before_minutes") + """) THEN
                ALTER TABLE courses
                ADD COLUMN attendance_before_minutes INTEGER NOT NULL DEFAULT 30;
            END IF;
        END $$;
    """)

    # 3. Add attendance_after_minutes
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("courses", "attendance_after_minutes") + """) THEN
                ALTER TABLE courses
                ADD COLUMN attendance_after_minutes INTEGER NOT NULL DEFAULT 30;
            END IF;
        END $$;
    """)

    # 4. Add department_id (optional)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("courses", "department_id") + """) THEN
                ALTER TABLE courses
                ADD COLUMN department_id UUID REFERENCES departments(id) ON DELETE SET NULL;
            END IF;
        END $$;
    """)

    # 5. Add check constraint on attendance_mode
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'ck_courses_attendance_mode'
            ) THEN
                ALTER TABLE courses
                ADD CONSTRAINT ck_courses_attendance_mode
                CHECK (attendance_mode IN ('fixed', 'flexible', 'custom'));
            END IF;
        END $$;
    """)


def downgrade() -> None:
    op.execute("DROP CONSTRAINT IF EXISTS ck_courses_attendance_mode")
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "department_id") + """) THEN
                ALTER TABLE courses DROP COLUMN IF EXISTS department_id;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "attendance_after_minutes") + """) THEN
                ALTER TABLE courses DROP COLUMN IF EXISTS attendance_after_minutes;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "attendance_before_minutes") + """) THEN
                ALTER TABLE courses DROP COLUMN IF EXISTS attendance_before_minutes;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "attendance_mode") + """) THEN
                ALTER TABLE courses DROP COLUMN IF EXISTS attendance_mode;
            END IF;
        END $$;
    """)
