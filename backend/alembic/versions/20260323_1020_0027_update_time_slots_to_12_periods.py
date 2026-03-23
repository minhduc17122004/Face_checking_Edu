"""Update time_slots: replace 8 periods with 12 periods (ĐH Kinh tế – ĐH Đà Nẵng timetable).

Revision ID: 202603231020_0027_update_time_slots_to_12_periods
Revises: 0026_drop_schedule_device_room_columns
Create Date: 2026-03-23

Changes:
1. DELETE all existing time_slots rows (8 periods)
2. INSERT 12 new time_slots rows matching ĐH Kinh tế official timetable

Note: Any existing schedules referencing old time_slot IDs will break.
Verify no active schedules reference periods 1-8 before running in production.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "202603231020_0027_update_time_slots_to_12_periods"
down_revision: Union[str, None] = "0026_drop_schedule_device_room_columns"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Official timetable — ĐH Kinh tế, ĐH Đà Nẵng
TIMESLOT_DATA = [
    # Morning block
    (1,  "07:00:00", "07:50:00"),
    (2,  "07:50:00", "08:40:00"),
    (3,  "08:50:00", "09:40:00"),
    (4,  "09:45:00", "10:35:00"),
    (5,  "10:35:00", "11:25:00"),
    (6,  "11:35:00", "12:25:00"),
    # Afternoon/Evening block
    (7,  "13:30:00", "14:20:00"),
    (8,  "14:20:00", "15:10:00"),
    (9,  "15:20:00", "16:10:00"),
    (10, "16:15:00", "17:05:00"),
    (11, "17:05:00", "17:55:00"),
    (12, "18:05:00", "18:55:00"),
]


def upgrade() -> None:
    # Remove old time slots
    op.execute("DELETE FROM time_slots")

    # Insert new 12-period timetable
    for period, start, end in TIMESLOT_DATA:
        op.execute(
            f"INSERT INTO time_slots (period_number, start_time, end_time) "
            f"VALUES ({period}, '{start}', '{end}')"
        )


def downgrade() -> None:
    # Revert to old 8-period timetable
    op.execute("DELETE FROM time_slots")

    OLD_DATA = [
        (1, "07:30:00", "08:15:00"),
        (2, "08:20:00", "09:05:00"),
        (3, "09:10:00", "09:55:00"),
        (4, "10:00:00", "10:45:00"),
        (5, "10:50:00", "11:35:00"),
        (6, "13:00:00", "13:45:00"),
        (7, "13:50:00", "14:35:00"),
        (8, "14:40:00", "15:25:00"),
    ]
    for period, start, end in OLD_DATA:
        op.execute(
            f"INSERT INTO time_slots (period_number, start_time, end_time) "
            f"VALUES ({period}, '{start}', '{end}')"
        )
