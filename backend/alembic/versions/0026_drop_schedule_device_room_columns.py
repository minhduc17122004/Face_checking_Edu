"""Drop schedule.room and device.room string columns — Phase 9 final step.

Revision ID: 0026_drop_schedule_device_room_columns
Revises: 0025_migrate_room_string_to_room_id
Create Date: 2026-03-21

Changes:
1. Drop schedules.room column (string) — room now accessed via course.room_id
2. Drop devices.room column (string) — room_id FK replaces it

After this migration:
- Room domain is fully normalized via rooms table
- Anti-cheat uses FK-based matching: device.room_id == course.room_id
- schedules no longer store room independently (they inherit from course)

Note: This migration is irreversible without data loss. Ensure migration
0025 has been applied successfully before running this.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0026_drop_schedule_device_room_columns"
down_revision: Union[str, None] = "0025_migrate_room_string_to_room_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop schedule.room column
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'schedules' AND column_name = 'room'
            ) THEN
                ALTER TABLE schedules DROP COLUMN room;
            END IF;
        END $$;
        """
    )

    # Drop device.room column
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'devices' AND column_name = 'room'
            ) THEN
                ALTER TABLE devices DROP COLUMN room;
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    # Re-add columns (data will be lost — rollback only for emergency)
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'schedules' AND column_name = 'room'
            ) THEN
                ALTER TABLE schedules ADD COLUMN room VARCHAR(100);
            END IF;
        END $$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'devices' AND column_name = 'room'
            ) THEN
                ALTER TABLE devices ADD COLUMN room VARCHAR(100);
            END IF;
        END $$;
        """
    )
