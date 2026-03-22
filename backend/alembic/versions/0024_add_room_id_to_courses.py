"""Add room_id FK to courses table — Phase 9 room assignment integration.

Revision ID: 0024_add_room_id_to_courses
Revises: 0023_add_rooms_table
Create Date: 2026-03-21

Changes:
1. Add room_id UUID column to courses table
2. Add FK constraint courses.room_id → rooms.id (ON DELETE SET NULL)
3. Add index for fast lookups

Rationale:
- Each course now has a primary room assigned
- Enables FK-based anti-cheat: device.room_id == course.room_id
- Replaces indirect room lookup through schedule.room
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0024_add_room_id_to_courses"
down_revision: Union[str, None] = "0023_add_rooms_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "courses",
        sa.Column(
            "room_id",
            sa.UUID(),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_courses_room_id", "courses", ["room_id"])


def downgrade() -> None:
    op.drop_index("ix_courses_room_id", table_name="courses")
    op.drop_column("courses", "room_id")
