"""Refactor attendance_mode: rename 'fixed' -> 'preset', update CHECK constraint.

Revision ID: 0021_refactor_attendance_mode_enum
Revises: 0020_add_performance_indexes
Create Date: 2026-03-21

Changes:
1. Update courses.attendance_mode values: 'fixed' -> 'preset'
2. Drop old CHECK constraint if exists, add new one with 'preset'
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0021_refactor_attendance_mode_enum"
down_revision: Union[str, None] = "0020_add_performance_indexes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Update existing 'fixed' values to 'preset'
    op.execute(
        "UPDATE courses SET attendance_mode = 'preset' WHERE attendance_mode = 'fixed'"
    )

    # 2. Drop old CHECK constraint if it had 'fixed' and create updated one
    # 0018 created 'ck_courses_attendance_mode' with fixed/flexible/custom
    op.execute(
        """
        DO $$
        BEGIN
            -- Drop old constraint if it exists
            ALTER TABLE courses DROP CONSTRAINT IF EXISTS ck_courses_attendance_mode;
            -- Also handle any legacy constraint name from 0018
            ALTER TABLE courses DROP CONSTRAINT IF EXISTS ck_courses_attendance_mode_legacy;
        EXCEPTION WHEN OTHERS THEN
            NULL;  -- ignore if already dropped
        END $$;
        """
    )

    # 3. Add updated CHECK constraint with 'preset' instead of 'fixed'
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'ck_courses_attendance_mode'
            ) THEN
                ALTER TABLE courses
                ADD CONSTRAINT ck_courses_attendance_mode
                CHECK (attendance_mode IN ('preset', 'flexible', 'custom'));
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    # Revert 'preset' back to 'fixed'
    op.execute(
        "UPDATE courses SET attendance_mode = 'fixed' WHERE attendance_mode = 'preset'"
    )
    op.execute(
        """
        DO $$
        BEGIN
            ALTER TABLE courses DROP CONSTRAINT IF EXISTS ck_courses_attendance_mode;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'ck_courses_attendance_mode'
            ) THEN
                ALTER TABLE courses
                ADD CONSTRAINT ck_courses_attendance_mode
                CHECK (attendance_mode IN ('fixed', 'flexible', 'custom'));
            END IF;
        END $$;
        """
    )
