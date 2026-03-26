"""Phase 9: Finalize device-based attendance — remove room_id, add audit logs, expand status.

Revision ID: 0030_finalize_phase9
Revises: 0029_add_device_attendance_tables
Create Date: 2026-03-24

Changes:
1. Drop room_id column from attendance table (no longer needed — derived from session)
2. Expand ck_attendance_status to include 'early' and 'on_time'
3. Create attendance_audit_logs table
4. Add production indexes for Phase 9 queries
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0030_finalize_phase9"
down_revision: Union[str, None] = "0029_add_device_attendance_tables"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. Drop room_id FK column from attendance ─────────────────────────────
    # First drop the index that was added in 0029
    op.drop_index("ix_attendance_room_id", table_name="attendance")
    op.drop_column("attendance", "room_id")

    # ── 2. Expand status constraint to include early / on_time ────────────────
    op.drop_constraint("ck_attendance_status", "attendance", type_="check")
    op.create_check_constraint(
        "ck_attendance_status",
        "attendance",
        "status IN ('present', 'late', 'absent', 'early', 'on_time')",
    )

    # ── 3. Create attendance_audit_logs table ────────────────────────────────
    op.create_table(
        "attendance_audit_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("student_id", sa.Integer(), nullable=False),
        sa.Column(
            "session_id", postgresql.UUID(as_uuid=True), nullable=False
        ),
        sa.Column(
            "device_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("devices.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("action", sa.String(20), nullable=False),
        sa.Column("old_status", sa.String(20), nullable=True),
        sa.Column("new_status", sa.String(20), nullable=True),
        sa.Column("minutes_diff", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_attendance_audit_id", "attendance_audit_logs", ["id"])
    op.create_index(
        "ix_attendance_audit_session_student",
        "attendance_audit_logs",
        ["session_id", "student_id"],
    )
    op.create_index(
        "ix_attendance_audit_session", "attendance_audit_logs", ["session_id"]
    )
    op.create_index(
        "ix_attendance_audit_student", "attendance_audit_logs", ["student_id"]
    )
    op.create_index(
        "ix_attendance_audit_created", "attendance_audit_logs", ["created_at"]
    )

    # ix_attendance_session_student was created in 0029 but add covering index
    # ix_attendance_checkin_time was created in 0029
    # ix_sessions_course_start was created in 0028/earlier


def downgrade() -> None:
    # ── Rollback attendance_audit_logs ───────────────────────────────────────
    op.drop_index("ix_attendance_audit_created", table_name="attendance_audit_logs")
    op.drop_index("ix_attendance_audit_student", table_name="attendance_audit_logs")
    op.drop_index("ix_attendance_audit_session", table_name="attendance_audit_logs")
    op.drop_index(
        "ix_attendance_audit_session_student", table_name="attendance_audit_logs"
    )
    op.drop_index("ix_attendance_audit_id", table_name="attendance_audit_logs")
    op.drop_table("attendance_audit_logs")

    # ── Rollback status constraint ────────────────────────────────────────────
    op.drop_constraint("ck_attendance_status", "attendance", type_="check")
    op.create_check_constraint(
        "ck_attendance_status",
        "attendance",
        "status IN ('present', 'late', 'absent')",
    )

    # ── Rollback room_id column ───────────────────────────────────────────────
    op.add_column(
        "attendance",
        sa.Column(
            "room_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("rooms.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_attendance_room_id", "attendance", ["room_id"])
