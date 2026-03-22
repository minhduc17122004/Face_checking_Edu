"""Refactor device: remove course_id, decouple device from course binding.

Revision ID: 0022_refactor_device_course_to_room
Revises: 0021_refactor_attendance_mode_enum
Create Date: 2026-03-21

Changes:
1. Drop course_id FK column from devices (soft binding removed)
2. Add partial index ix_devices_active_room (already done in 0020, this is belt-and-suspenders)
3. Update device-course matching logic in anti_cheat_service:
   OLD: device.course_id == session.course_id
   NEW: device.room == session.schedule.room (both must be set)
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0022_refactor_device_course_to_room"
down_revision: Union[str, None] = "0021_refactor_attendance_mode_enum"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Drop course_id FK from devices
    # First, remove any FK constraint that might reference courses
    op.execute(
        """
        DO $$
        BEGIN
            -- Try to drop FK constraint if it exists (PostgreSQL names it)
            ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_course_id_fkey;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END $$;
        """
    )
    # 2. Drop the course_id column
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'devices' AND column_name = 'course_id'
            ) THEN
                ALTER TABLE devices DROP COLUMN course_id;
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    # Re-add course_id column (for rollback only)
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'devices' AND column_name = 'course_id'
            ) THEN
                ALTER TABLE devices ADD COLUMN course_id UUID REFERENCES courses(id) ON DELETE SET NULL;
            END IF;
        END $$;
        """
    )
