"""add mode and room_id to attendance_configs

Revision ID: 20260325_att_cfg_mode_room
Revises: fc7a550c7bb0
Create Date: 2026-03-25 16:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "20260325_att_cfg_mode_room"
down_revision: Union[str, None] = "0031_remove_timezone_from_time_slots"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "attendance_configs",
        sa.Column("room_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.add_column(
        "attendance_configs",
        sa.Column("mode", sa.String(length=20), nullable=True),
    )
    op.create_index(
        "ix_attendance_configs_room_id",
        "attendance_configs",
        ["room_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_attendance_configs_room_id_rooms",
        "attendance_configs",
        "rooms",
        ["room_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_check_constraint(
        "ck_attendance_configs_mode",
        "attendance_configs",
        "mode IN ('FIXED', 'FLEXIBLE')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_attendance_configs_mode", "attendance_configs", type_="check")
    op.drop_constraint("fk_attendance_configs_room_id_rooms", "attendance_configs", type_="foreignkey")
    op.drop_index("ix_attendance_configs_room_id", table_name="attendance_configs")
    op.drop_column("attendance_configs", "mode")
    op.drop_column("attendance_configs", "room_id")
