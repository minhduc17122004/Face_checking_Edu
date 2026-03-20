"""Refactor database schema: rename tables, remove redundancy, enforce constraints.

Revision ID: 0014_refactor_schema
Revises: 0013
Create Date: 2026-03-20

Changes:
1. Rename tables:
   - academic_classes → student_groups
   - classes → courses
   - classroom_students → course_enrollments

2. Rename columns:
   - classes.teacher_id → courses.instructor_id
   - classes.class_name → courses.course_name
   - sessions.classroom_id → sessions.course_id
   - schedules.classroom_id → schedules.course_id
   - devices.classroom_id → devices.course_id
   - students.academic_class_id → students.student_group_id
   - schedules.subject_name → schedules.room

3. Remove redundant fields:
   - Remove students.avatar_url (use users.avatar_url)
   - Remove students.has_avatar (derived from users.avatar_url)
   - Remove students.attachment_id (infrastructure)
   - Remove students.is_synced (infrastructure)
   - Remove students.name (use users.full_name)
   - Remove teachers.avatar_url (use users.avatar_url)

4. Enforce strict 1:1 relationships:
   - Make students.user_id NOT NULL UNIQUE
   - Keep teachers.user_id NOT NULL UNIQUE (already enforced)

5. Remove is_deleted columns (use only deleted_at):
   - users.is_deleted → users.deleted_at only
   - (repeat for all tables)

6. Add new fields:
   - courses.course_code
   - devices.device_name, devices.mac_address
   - face_embeddings.quality_score, face_embeddings.captured_at
   - refresh_tokens.device_info (JSONB)
   - sessions.session_date
   - sessions.checkin_window_start, sessions.checkin_window_end
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0014_refactor_schema"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    """Check if column exists in table."""
    return f"""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = '{table}' AND column_name = '{column}'
    """


def _table_exists(table: str) -> bool:
    """Check if table exists."""
    return f"""
        SELECT 1 FROM information_schema.tables
        WHERE table_name = '{table}'
    """


def upgrade() -> None:
    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 1: Copy avatar data from students/teachers to users
    # ─────────────────────────────────────────────────────────────────────────────
    op.execute("""
        UPDATE users u
        SET avatar_url = (
            SELECT s.avatar_url
            FROM students s
            WHERE s.user_id = u.id AND s.avatar_url IS NOT NULL
            LIMIT 1
        )
        WHERE EXISTS (
            SELECT 1 FROM students s WHERE s.user_id = u.id AND s.avatar_url IS NOT NULL
        )
    """)

    op.execute("""
        UPDATE users u
        SET avatar_url = (
            SELECT t.avatar_url
            FROM teachers t
            WHERE t.user_id = u.id AND t.avatar_url IS NOT NULL
            LIMIT 1
        )
        WHERE EXISTS (
            SELECT 1 FROM teachers t WHERE t.user_id = u.id AND t.avatar_url IS NOT NULL
        )
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 2: Rename tables (if not already renamed)
    # ─────────────────────────────────────────────────────────────────────────────
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _table_exists("academic_classes") + """) THEN
                ALTER TABLE academic_classes RENAME TO student_groups;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _table_exists("classes") + """) THEN
                ALTER TABLE classes RENAME TO courses;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _table_exists("classroom_students") + """) THEN
                ALTER TABLE classroom_students RENAME TO course_enrollments;
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 3: Rename columns in courses table (if not already renamed)
    # ─────────────────────────────────────────────────────────────────────────────
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "teacher_id") + """) THEN
                ALTER TABLE courses RENAME COLUMN teacher_id TO instructor_id;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("courses", "class_name") + """) THEN
                ALTER TABLE courses RENAME COLUMN class_name TO course_name;
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 4: Rename foreign key columns in other tables
    # ─────────────────────────────────────────────────────────────────────────────
    # Sessions: classroom_id → course_id
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("sessions", "classroom_id") + """) THEN
                ALTER TABLE sessions RENAME COLUMN classroom_id TO course_id;
            END IF;
        END $$;
    """)

    # Schedules: classroom_id → course_id
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("schedules", "classroom_id") + """) THEN
                ALTER TABLE schedules RENAME COLUMN classroom_id TO course_id;
            END IF;
        END $$;
    """)

    # Devices: classroom_id → course_id
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("devices", "classroom_id") + """) THEN
                ALTER TABLE devices RENAME COLUMN classroom_id TO course_id;
            END IF;
        END $$;
    """)

    # Students: academic_class_id → student_group_id
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("students", "academic_class_id") + """) THEN
                ALTER TABLE students RENAME COLUMN academic_class_id TO student_group_id;
            END IF;
        END $$;
    """)

    # Schedules: subject_name → room
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("schedules", "subject_name") + """) THEN
                ALTER TABLE schedules RENAME COLUMN subject_name TO room;
            END IF;
        END $$;
    """)

    # Sessions: Rename checkin times
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("sessions", "checkin_start_time") + """) THEN
                ALTER TABLE sessions RENAME COLUMN checkin_start_time TO checkin_window_start;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("sessions", "checkin_end_time") + """) THEN
                ALTER TABLE sessions RENAME COLUMN checkin_end_time TO checkin_window_end;
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 5: Add new columns (if not already exist)
    # ─────────────────────────────────────────────────────────────────────────────
    # courses.course_code
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("courses", "course_code") + """) THEN
                ALTER TABLE courses ADD COLUMN course_code VARCHAR(50);
            END IF;
        END $$;
    """)

    # devices: add device_name, mac_address
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("devices", "device_name") + """) THEN
                ALTER TABLE devices ADD COLUMN device_name VARCHAR(100);
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("devices", "mac_address") + """) THEN
                ALTER TABLE devices ADD COLUMN mac_address VARCHAR(17);
            END IF;
        END $$;
    """)

    # face_embeddings: add quality_score, captured_at
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("face_embeddings", "quality_score") + """) THEN
                ALTER TABLE face_embeddings ADD COLUMN quality_score FLOAT;
            END IF;
        END $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("face_embeddings", "captured_at") + """) THEN
                ALTER TABLE face_embeddings ADD COLUMN captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            END IF;
        END $$;
    """)

    # refresh_tokens: add device_info
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("refresh_tokens", "device_info") + """) THEN
                ALTER TABLE refresh_tokens ADD COLUMN device_info JSONB;
            END IF;
        END $$;
    """)

    # sessions: add session_date (as regular DATE column)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (""" + _column_exists("sessions", "session_date") + """) THEN
                ALTER TABLE sessions ADD COLUMN session_date DATE;
                UPDATE sessions SET session_date = start_time::date WHERE start_time IS NOT NULL;
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 6: Remove redundant columns (if exist)
    # ─────────────────────────────────────────────────────────────────────────────
    # Remove from students
    for col in ["avatar_url", "has_avatar", "attachment_id", "is_synced", "name"]:
        op.execute("""
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = 'students' AND column_name = '%s'
                ) THEN
                    ALTER TABLE students DROP COLUMN IF EXISTS %s;
                END IF;
            END $$;
        """ % (col, col))

    # Remove from teachers
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (""" + _column_exists("teachers", "avatar_url") + """) THEN
                ALTER TABLE teachers DROP COLUMN IF EXISTS avatar_url;
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 7: Enforce strict 1:1 relationships
    # ─────────────────────────────────────────────────────────────────────────────
    # Make students.user_id NOT NULL
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'students' AND column_name = 'user_id'
                       AND is_nullable = 'YES') THEN
                ALTER TABLE students ALTER COLUMN user_id SET NOT NULL;
            END IF;
        END $$;
    """)

    # Add UNIQUE constraint on students.user_id
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_students_user_id'
            ) THEN
                ALTER TABLE students ADD CONSTRAINT uq_students_user_id UNIQUE (user_id);
            END IF;
        END $$;
    """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 8: Remove is_deleted columns (keep only deleted_at)
    # ─────────────────────────────────────────────────────────────────────────────
    tables_with_is_deleted = [
        "users",
        "teachers",
        "students",
        "student_groups",
        "courses",
        "schedules",
        "sessions",
        "attendance",
        "devices",
        "face_embeddings",
    ]

    for table in tables_with_is_deleted:
        op.execute(f"""
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_name = '{table}' AND column_name = 'is_deleted'
                ) THEN
                    ALTER TABLE {table} DROP COLUMN IF EXISTS is_deleted;
                END IF;
            END $$;
        """)

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 9: Update indexes
    # ─────────────────────────────────────────────────────────────────────────────
    # Rename indexes for renamed columns/tables
    op.execute("DROP INDEX IF EXISTS ix_sessions_classroom_start")
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_sessions_course_start
        ON sessions(course_id, start_time)
    """)

    op.execute("DROP INDEX IF EXISTS ix_classroom_students_class_student")

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 10: Add status index to attendance
    # ─────────────────────────────────────────────────────────────────────────────
    op.create_index(
        "ix_attendance_status",
        "attendance",
        ["status"],
        if_not_exists=True,
    )

    # ─────────────────────────────────────────────────────────────────────────────
    # PHASE 11: Make session_date NOT NULL
    # ─────────────────────────────────────────────────────────────────────────────
    op.execute("""
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'sessions' AND column_name = 'session_date'
                       AND is_nullable = 'YES') THEN
                ALTER TABLE sessions ALTER COLUMN session_date SET NOT NULL;
            END IF;
        END $$;
    """)


def downgrade() -> None:
    # ─────────────────────────────────────────────────────────────────────────────
    # NOTE: This is a one-way migration. Downgrade is not supported.
    # Restore from backup if needed.
    # ─────────────────────────────────────────────────────────────────────────────
    raise NotImplementedError(
        "Downgrade from 0014_refactor_schema is not supported. "
        "Please restore from backup."
    )
