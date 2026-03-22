"""Migrate room string data to rooms table and map room_id references — Phase 9.

Revision ID: 0025_migrate_room_string_to_room_id
Revises: 0024_add_room_id_to_courses
Create Date: 2026-03-21

Changes:
1. Insert distinct room strings from schedules into rooms table
2. Insert distinct room strings from devices into rooms table
3. Map course.room_id using schedule.course + schedule.room matching
4. Map device.room_id using room code matching

Strategy:
- Unique room strings are inserted into rooms table
- course.room_id is set by finding rooms matching schedule.room for that course
- device.room_id is set by matching device.room == rooms.code

Note: This migration is idempotent — running twice has no effect due to
ON CONFLICT DO NOTHING clauses.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0025_migrate_room_string_to_room_id"
down_revision: Union[str, None] = "0024_add_room_id_to_courses"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add room_id to devices since it was missed in earlier migrations
    op.add_column(
        "devices",
        sa.Column(
            "room_id",
            sa.UUID(),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_devices_room_id", "devices", ["room_id"], if_not_exists=True)

    # Step 1: Insert distinct rooms from schedules.room into rooms table
    op.execute(
        """
        INSERT INTO rooms (id, code, name, created_at, updated_at)
        SELECT DISTINCT ON (s.room)
            gen_random_uuid(),
            s.room,
            s.room,
            NOW(),
            NOW()
        FROM schedules s
        WHERE s.room IS NOT NULL
          AND s.room <> ''
          AND NOT EXISTS (
              SELECT 1 FROM rooms r WHERE r.code = s.room
          )
        ON CONFLICT (code) DO NOTHING;
        """
    )

    # Step 2: Insert distinct rooms from devices.room into rooms table
    op.execute(
        """
        INSERT INTO rooms (id, code, name, created_at, updated_at)
        SELECT DISTINCT ON (d.room)
            gen_random_uuid(),
            d.room,
            d.room,
            NOW(),
            NOW()
        FROM devices d
        WHERE d.room IS NOT NULL
          AND d.room <> ''
          AND NOT EXISTS (
              SELECT 1 FROM rooms r WHERE r.code = d.room
          )
        ON CONFLICT (code) DO NOTHING;
        """
    )

    # Step 3: Map course.room_id via schedule.room matching
    # For each course, find the first schedule with a room and assign that room_id
    op.execute(
        """
        UPDATE courses c
        SET room_id = (
            SELECT r.id
            FROM rooms r
            JOIN schedules s ON s.room = r.code
            WHERE s.course_id = c.id
              AND s.room IS NOT NULL
              AND s.room <> ''
              AND s.deleted_at IS NULL
            LIMIT 1
        )
        WHERE c.room_id IS NULL
          AND EXISTS (
              SELECT 1
              FROM schedules s2
              WHERE s2.course_id = c.id
                AND s2.room IS NOT NULL
                AND s2.room <> ''
                AND s2.deleted_at IS NULL
          );
        """
    )

    # Step 4: Map device.room_id via room code matching
    op.execute(
        """
        UPDATE devices d
        SET room_id = (
            SELECT r.id
            FROM rooms r
            WHERE r.code = d.room
              AND r.deleted_at IS NULL
            LIMIT 1
        )
        WHERE d.room IS NOT NULL
          AND d.room <> ''
          AND d.room_id IS NULL;
        """
    )


def downgrade() -> None:
    # Cannot easily reverse data mapping — this is a one-way data migration
    # For rollback, courses.room_id and devices.room_id must be manually managed
    op.execute("UPDATE courses SET room_id = NULL;")
    op.execute("UPDATE devices SET room_id = NULL;")
