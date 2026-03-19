"""Expand database schema for production.

Creates new tables:
- time_slots: Global period definitions
- classroom_students: Many-to-many classroom-student relationships
- schedules: Weekly class schedule definitions
- sessions: Actual attendance sessions (instances of scheduled classes)
- attendance: New core attendance table (replaces logic from attendance_records)

Also modifies:
- devices: Adds classroom_id FK

Revision ID: 0003
Revises: 0002
Create Date: 2026-03-19
"""
from typing import Sequence, Union
import uuid

import sqlalchemy as sa
from alembic import op

# revision identifiers
revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. TIME_SLOTS ──────────────────────────────────────────────────────────
    op.create_table(
        "time_slots",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("period_number", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.Time(timezone=True), nullable=False),
        sa.Column("end_time", sa.Time(timezone=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    # Insert default time slots (8 periods)
    op.execute(
        """
        INSERT INTO time_slots (period_number, start_time, end_time) VALUES
        (1, '07:30:00', '08:15:00'),
        (2, '08:20:00', '09:05:00'),
        (3, '09:10:00', '09:55:00'),
        (4, '10:00:00', '10:45:00'),
        (5, '10:50:00', '11:35:00'),
        (6, '13:00:00', '13:45:00'),
        (7, '13:50:00', '14:35:00'),
        (8, '14:40:00', '15:25:00');
        """
    )

    # ── 2. CLASSROOM_STUDENTS ──────────────────────────────────────────────────
    op.create_table(
        "classroom_students",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            "classroom_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "student_id",
            sa.Integer(),
            sa.ForeignKey("students.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "enrolled_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("classroom_id", "student_id", name="uq_classroom_student"),
    )

    # ── 3. SCHEDULES ───────────────────────────────────────────────────────────
    op.create_table(
        "schedules",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            "classroom_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("day_of_week", sa.Integer(), nullable=False),
        sa.Column(
            "time_slot_id", sa.Integer(), sa.ForeignKey("time_slots.id"), nullable=False
        ),
        sa.Column("subject_name", sa.String(255), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "classroom_id", "day_of_week", "time_slot_id", name="uq_schedule"
        ),
        sa.CheckConstraint("day_of_week BETWEEN 1 AND 7", name="ck_day_of_week"),
    )

    # ── 4. SESSIONS ───────────────────────────────────────────────────────────
    op.create_table(
        "sessions",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            "classroom_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "schedule_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("schedules.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("session_date", sa.Date(), nullable=False),
        sa.Column("start_time", sa.Time(timezone=True), nullable=False),
        sa.Column("end_time", sa.Time(timezone=True), nullable=True),
        sa.Column("status", sa.String(20), server_default="scheduled"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "status IN ('scheduled', 'active', 'closed')", name="ck_session_status"
        ),
    )

    # ── 5. DEVICES: Add classroom_id ───────────────────────────────────────────
    op.add_column(
        "devices",
        sa.Column(
            "classroom_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    # ── 6. ATTENDANCE (New core table) ────────────────────────────────────────
    op.create_table(
        "attendance",
        sa.Column(
            "id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            primary_key=True,
            default=uuid.uuid4,
        ),
        sa.Column(
            "session_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "student_id",
            sa.Integer(),
            sa.ForeignKey("students.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("checkin_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column(
            "device_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("devices.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "session_id", "student_id", name="uq_attendance_session_student"
        ),
        sa.CheckConstraint(
            "status IN ('present', 'late', 'absent')", name="ck_attendance_status"
        ),
    )

    # ── 7. Indexes ────────────────────────────────────────────────────────────
    op.create_index(
        "idx_classroom_students_classroom",
        "classroom_students",
        ["classroom_id"],
    )
    op.create_index(
        "idx_classroom_students_student", "classroom_students", ["student_id"]
    )
    op.create_index("idx_schedules_classroom", "schedules", ["classroom_id"])
    op.create_index("idx_schedules_day", "schedules", ["day_of_week"])
    op.create_index(
        "idx_sessions_classroom_date", "sessions", ["classroom_id", "session_date"]
    )
    op.create_index("idx_sessions_status", "sessions", ["status"])
    op.create_index("idx_attendance_session", "attendance", ["session_id"])
    op.create_index("idx_attendance_student", "attendance", ["student_id"])
    op.create_index("idx_devices_classroom", "devices", ["classroom_id"])

    # ── 8. Table Comments ─────────────────────────────────────────────────────
    op.execute(
        "COMMENT ON TABLE attendance IS 'New attendance table - replaces logic from attendance_records'"
    )
    op.execute(
        "COMMENT ON TABLE sessions IS 'Attendance session - actual instance of a scheduled class'"
    )
    op.execute(
        "COMMENT ON TABLE schedules IS 'Weekly class schedule - links classroom to day and time slot'"
    )
    op.execute("COMMENT ON TABLE time_slots IS 'Global period definitions for school timetable'")


def downgrade() -> None:
    # Drop indexes first
    op.drop_index("idx_devices_classroom", table_name="devices")
    op.drop_index("idx_attendance_student", table_name="attendance")
    op.drop_index("idx_attendance_session", table_name="attendance")
    op.drop_index("idx_sessions_status", table_name="sessions")
    op.drop_index("idx_sessions_classroom_date", table_name="sessions")
    op.drop_index("idx_schedules_day", table_name="schedules")
    op.drop_index("idx_schedules_classroom", table_name="schedules")
    op.drop_index("idx_classroom_students_student", table_name="classroom_students")
    op.drop_index("idx_classroom_students_classroom", table_name="classroom_students")

    # Drop tables in reverse order (respecting FK dependencies)
    op.drop_table("attendance")
    op.drop_table("sessions")
    op.drop_table("schedules")
    op.drop_table("classroom_students")
    op.drop_table("time_slots")

    # Drop column from devices
    op.drop_column("devices", "classroom_id")
