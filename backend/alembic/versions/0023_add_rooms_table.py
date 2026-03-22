"""Add rooms table — central room/location domain for Phase 9.

Revision ID: 0023_add_rooms_table
Revises: 0022_refactor_device_course_to_room
Create Date: 2026-03-21

Changes:
1. Create rooms table with proper relational domain model
2. Add unique constraint on room code
3. Add soft delete support

Rationale:
- Replaces string-based room fields in schedules and devices
- Enables FK-based room matching (device.room_id == course.room_id)
- Standardizes room data across the entire system
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0023_add_rooms_table"
down_revision: Union[str, None] = "0022_refactor_device_course_to_room"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "rooms",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("building", sa.String(length=100), nullable=True),
        sa.Column("floor", sa.Integer(), nullable=True),
        sa.Column("capacity", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by", sa.UUID(), nullable=True),
        sa.Column("updated_by", sa.UUID(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index("ix_rooms_code", "rooms", ["code"], unique=True)
    op.create_index("ix_rooms_deleted_at", "rooms", ["deleted_at"])

    # CHECK: code must be non-empty
    op.execute(
        """
        ALTER TABLE rooms
        ADD CONSTRAINT ck_rooms_code_not_empty
        CHECK (code <> ''::text);
        """
    )


def downgrade() -> None:
    op.drop_table("rooms")
