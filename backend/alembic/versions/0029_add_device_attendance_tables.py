"""Phase 9: Device-based Attendance Management

Revision ID: 0029_add_device_attendance_tables
Revises: fc7a550c7bb0
Create Date: 2026-03-24

Changes:
1. Create attendance_configs table (per-session early/late allowance)
2. Create device_requests table (device permission approval flow)
3. Add is_global, status columns to devices table
4. Add minutes_diff, room_id columns to attendance table

Relationships are managed by SQLAlchemy models (no migration needed).
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0029_add_device_attendance_tables"
down_revision: Union[str, None] = "fc7a550c7bb0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. attendance_configs table ─────────────────────────────────────────
    op.create_table(
        "attendance_configs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("early_allowance", sa.Integer(), nullable=False, default=15),
        sa.Column("late_allowance", sa.Integer(), nullable=False, default=15),
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
    )
    op.create_index(
        "ix_attendance_configs_session_id",
        "attendance_configs",
        ["session_id"],
        unique=True,
    )
    op.create_index("ix_attendance_configs_id", "attendance_configs", ["id"])

    # ── 2. device_requests table ─────────────────────────────────────────────
    op.create_table(
        "device_requests",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_code", sa.String(50), nullable=False),
        sa.Column("device_name", sa.String(100), nullable=True),
        sa.Column(
            "room_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "requested_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="PENDING",
        ),
        sa.Column(
            "reviewed_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("admin_note", sa.String(255), nullable=True),
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
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.create_index("ix_device_requests_id", "device_requests", ["id"])
    op.create_index("ix_device_requests_device_code", "device_requests", ["device_code"])
    op.create_index("ix_device_requests_status", "device_requests", ["status"])
    op.create_index("ix_device_requests_deleted_at", "device_requests", ["deleted_at"])
    op.create_index("ix_device_requests_room_id", "device_requests", ["room_id"])

    # ── 3. Add columns to devices table ─────────────────────────────────────
    op.add_column(
        "devices",
        sa.Column("is_global", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.add_column(
        "devices",
        sa.Column("status", sa.String(20), nullable=False, server_default="ACTIVE"),
    )

    # ── 4. Add columns to attendance table ──────────────────────────────────
    op.add_column(
        "attendance",
        sa.Column("minutes_diff", sa.Integer(), nullable=True),
    )
    op.add_column(
        "attendance",
        sa.Column(
            "room_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_attendance_minutes_diff", "attendance", ["minutes_diff"])
    op.create_index("ix_attendance_room_id", "attendance", ["room_id"])


def downgrade() -> None:
    # ── Rollback attendance ─────────────────────────────────────────────────
    op.drop_index("ix_attendance_room_id", table_name="attendance")
    op.drop_index("ix_attendance_minutes_diff", table_name="attendance")
    op.drop_column("attendance", "room_id")
    op.drop_column("attendance", "minutes_diff")

    # ── Rollback devices ─────────────────────────────────────────────────────
    op.drop_column("devices", "status")
    op.drop_column("devices", "is_global")

    # ── Rollback device_requests ─────────────────────────────────────────────
    op.drop_table("device_requests")

    # ── Rollback attendance_configs ──────────────────────────────────────────
    op.drop_table("attendance_configs")
