"""Add teacher_id FK to courses — decouple Course from User.instructor_id.

Revision ID: 0028_add_teacher_id_to_courses
Revises: 202603231020_0027_update_time_slots_to_12_periods
Create Date: 2026-03-23

Changes:
1. Add teacher_id INT column to courses table
2. Migrate existing instructor_id → teacher_id via teachers.user_id join
3. Drop instructor_id column (after data migration)

Goal:
- Course belongs to Teacher (domain entity), not directly to User
- Allows teacher reassignment without touching User records
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0028_add_teacher_id_to_courses"
down_revision: Union[str, None] = "202603231020_0027_update_time_slots_to_12_periods"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Step 1: Add teacher_id column (nullable, no FK yet to allow migration)
    op.add_column(
        "courses",
        sa.Column(
            "teacher_id",
            sa.Integer(),
            nullable=True,
        ),
    )
    op.create_index("ix_courses_teacher_id", "courses", ["teacher_id"])

    # Step 2: Migrate existing data from instructor_id → teacher_id
    # Map: courses.instructor_id (users.id) → teachers.id via teachers.user_id
    op.execute("""
        UPDATE courses
        SET teacher_id = teachers.id
        FROM teachers
        WHERE courses.instructor_id = teachers.user_id
          AND courses.teacher_id IS NULL
    """)

    # Step 3: Add FK constraint now that data is migrated
    op.create_foreign_key(
        "fk_courses_teacher_id",
        "courses",
        "teachers",
        ["teacher_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # Step 4: Drop instructor_id and its index
    op.drop_index("ix_courses_instructor_id", table_name="courses")
    op.drop_column("courses", "instructor_id")


def downgrade() -> None:
    # Revert: re-add instructor_id from teacher.user_id
    op.add_column(
        "courses",
        sa.Column(
            "instructor_id",
            sa.UUID(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_courses_instructor_id", "courses", ["instructor_id"])

    # Restore instructor_id from teacher.user_id
    op.execute("""
        UPDATE courses
        SET instructor_id = teachers.user_id
        FROM teachers
        WHERE courses.teacher_id = teachers.id
          AND courses.instructor_id IS NULL
    """)

    # Remove teacher_id
    op.drop_constraint("fk_courses_teacher_id", "courses", type_="foreignkey")
    op.drop_index("ix_courses_teacher_id", table_name="courses")
    op.drop_column("courses", "teacher_id")
