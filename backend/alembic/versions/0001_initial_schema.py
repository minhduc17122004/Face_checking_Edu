"""Initial schema — create all tables.

Revision ID: 0001
Revises: (none — this is the first migration)
Create Date: 2026-03-16 14:00:00.000000 UTC

Tables created (in FK-dependency order):
    1. users
    2. teachers  (FK → users)
    3. students  (FK → users, nullable)
    4. classes   (FK → users as teacher)
    5. face_embeddings  (FK → students)
    6. attendance_records  (FK → students, FK → classes nullable)
"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from alembic import op

# revision identifiers
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. users ───────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("role", sa.String(20), nullable=False, server_default="student"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_users_id", "users", ["id"])
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    # ── 2. teachers ────────────────────────────────────────────────────────
    op.create_table(
        "teachers",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("employee_code", sa.String(50), nullable=True, unique=True),
        sa.Column("phone", sa.String(20), nullable=True),
        sa.Column("department", sa.String(255), nullable=True),
        sa.Column("avatar_url", sa.Text(), nullable=True),
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
    op.create_index("ix_teachers_user_id", "teachers", ["user_id"])

    # ── 3. students ────────────────────────────────────────────────────────
    op.create_table(
        "students",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True, nullable=False),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("pin", sa.String(10), nullable=True),
        sa.Column("job_title", sa.String(100), nullable=True),
        sa.Column("avatar_url", sa.Text(), nullable=True),
        sa.Column("has_avatar", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("attachment_id", sa.String(255), nullable=True),
        sa.Column("is_synced", sa.Boolean(), nullable=False, server_default="false"),
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
    op.create_index("ix_students_user_id", "students", ["user_id"])

    # ── 4. classes ─────────────────────────────────────────────────────────
    op.create_table(
        "classes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("class_name", sa.String(255), nullable=False),
        sa.Column("subject", sa.String(255), nullable=True),
        sa.Column(
            "teacher_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_classes_id", "classes", ["id"])
    op.create_index("ix_classes_teacher_id", "classes", ["teacher_id"])

    # ── 5. face_embeddings ─────────────────────────────────────────────────
    op.create_table(
        "face_embeddings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column(
            "student_id",
            sa.Integer(),
            sa.ForeignKey("students.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("embedding_data", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
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
    op.create_index("ix_face_embeddings_id", "face_embeddings", ["id"])
    op.create_index("ix_face_embeddings_student_id", "face_embeddings", ["student_id"])

    # ── 6. attendance_records ──────────────────────────────────────────────
    op.create_table(
        "attendance_records",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column(
            "student_id",
            sa.Integer(),
            sa.ForeignKey("students.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "class_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("classes.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("record_type", sa.String(10), nullable=False, server_default="checkin"),
        sa.Column("checkin_time", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "sync_time",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("device_id", sa.String(255), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="present"),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
    )
    op.create_index("ix_attendance_records_id", "attendance_records", ["id"])
    op.create_index("ix_attendance_records_student_id", "attendance_records", ["student_id"])
    op.create_index("ix_attendance_records_class_id", "attendance_records", ["class_id"])

    # ── 6b. devices ────────────────────────────────────────────────────────
    op.create_table(
        "devices",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("device_name", sa.String(255), nullable=False),
        sa.Column("device_type", sa.String(50), nullable=True),
        sa.Column("location", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("last_seen", sa.DateTime(timezone=True), nullable=True),
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
    op.create_index("ix_devices_id", "devices", ["id"])

    # ── Composite index for duplicate detection ────────────────────────────
    op.create_index(
        "ix_attendance_dedup",
        "attendance_records",
        ["student_id", "checkin_time", "record_type"],
        unique=False,   # not unique — allow duplicates to be caught gracefully
    )


def downgrade() -> None:
    # Drop devices first
    op.drop_index("ix_devices_id", table_name="devices")
    op.drop_table("devices")

    # Drop in reverse dependency order
    op.drop_index("ix_attendance_dedup", table_name="attendance_records")
    op.drop_index("ix_attendance_records_class_id", table_name="attendance_records")
    op.drop_index("ix_attendance_records_student_id", table_name="attendance_records")
    op.drop_index("ix_attendance_records_id", table_name="attendance_records")
    op.drop_table("attendance_records")

    op.drop_index("ix_face_embeddings_student_id", table_name="face_embeddings")
    op.drop_index("ix_face_embeddings_id", table_name="face_embeddings")
    op.drop_table("face_embeddings")

    op.drop_index("ix_classes_teacher_id", table_name="classes")
    op.drop_index("ix_classes_id", table_name="classes")
    op.drop_table("classes")

    op.drop_index("ix_students_user_id", table_name="students")
    op.drop_table("students")

    op.drop_index("ix_teachers_user_id", table_name="teachers")
    op.drop_table("teachers")

    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_id", table_name="users")
    op.drop_table("users")
