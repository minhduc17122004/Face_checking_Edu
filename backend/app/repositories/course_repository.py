from __future__ import annotations
"""Course repository — async DB queries for the `courses` table."""
import uuid
from typing import Literal, Sequence

from sqlalchemy import select, func as sa_func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.models.course import Course
from app.models.teacher import Teacher
from app.models.schedule import Schedule


class CourseRepository:
    """All database interactions for the Course model."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, course_id: uuid.UUID) -> Course | None:
        result = await self.db.execute(
            select(Course)
            .options(
                joinedload(Course.teacher).joinedload(Teacher.user),
                joinedload(Course.department),
                joinedload(Course.room),
                selectinload(Course.schedules).joinedload(Schedule.time_slot)
            )
            .where(
                Course.id == course_id,
                Course.deleted_at.is_(None),
            )
        )
        return result.unique().scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 200) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .options(
                joinedload(Course.teacher).joinedload(Teacher.user),
                joinedload(Course.department),
                joinedload(Course.room),
                selectinload(Course.schedules).joinedload(Schedule.time_slot)
            )
            .where(Course.deleted_at.is_(None))
            .offset(skip)
            .limit(limit)
            .order_by(Course.created_at.desc())
        )
        return result.unique().scalars().all()

    async def get_by_teacher(
        self, teacher_id: int
    ) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .options(
                joinedload(Course.teacher).joinedload(Teacher.user),
                joinedload(Course.department),
                joinedload(Course.room),
                selectinload(Course.schedules).joinedload(Schedule.time_slot)
            )
            .where(
                Course.teacher_id == teacher_id,
                Course.deleted_at.is_(None),
            )
            .order_by(Course.created_at.desc())
        )
        return result.unique().scalars().all()

    async def count(self) -> int:
        result = await self.db.execute(
            select(sa_func.count()).select_from(Course).where(
                Course.deleted_at.is_(None)
            )
        )
        return result.scalar_one()

    async def search_by_name(self, name: str) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .options(
                joinedload(Course.teacher).joinedload(Teacher.user),
                joinedload(Course.department),
                joinedload(Course.room),
                selectinload(Course.schedules).joinedload(Schedule.time_slot)
            )
            .where(
                Course.course_name.ilike(f"%{name}%"),
                Course.deleted_at.is_(None),
            )
            .order_by(Course.course_name)
            .limit(50)
        )
        return result.unique().scalars().all()

    async def get_by_department(
        self, department_id: uuid.UUID
    ) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .options(
                joinedload(Course.teacher).joinedload(Teacher.user),
                joinedload(Course.department),
                joinedload(Course.room),
                selectinload(Course.schedules).joinedload(Schedule.time_slot)
            )
            .where(
                Course.department_id == department_id,
                Course.deleted_at.is_(None),
            )
            .order_by(Course.course_name)
        )
        return result.unique().scalars().all()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        course_name: str,
        teacher_id: int | None = None,
        course_code: str | None = None,
        department_id: uuid.UUID | None = None,
        room_id: uuid.UUID | None = None,
        attendance_mode: Literal["preset", "flexible", "custom"] = "preset",
        attendance_before_minutes: int = 30,
        attendance_after_minutes: int = 30,
    ) -> Course:
        course = Course(
            course_name=course_name,
            teacher_id=teacher_id,
            course_code=course_code,
            department_id=department_id,
            room_id=room_id,
            attendance_mode=attendance_mode,
            attendance_before_minutes=attendance_before_minutes,
            attendance_after_minutes=attendance_after_minutes,
        )
        self.db.add(course)
        await self.db.flush()
        await self.db.refresh(course)
        # Re-fetch with all eager loads for service layer properties
        res = await self.get_by_id(course.id)
        return res if res else course

    async def update(
        self,
        course: Course,
        *,
        course_name: str | None = None,
        course_code: str | None = None,
        teacher_id: int | None = None,
        department_id: uuid.UUID | None = None,
        room_id: uuid.UUID | None = None,
        attendance_mode: str | None = None,
        attendance_before_minutes: int | None = None,
        attendance_after_minutes: int | None = None,
    ) -> Course:
        if course_name is not None:
            course.course_name = course_name
        if course_code is not None:
            course.course_code = course_code
        if teacher_id is not None:
            course.teacher_id = teacher_id
        if department_id is not None:
            course.department_id = department_id
        if room_id is not None:
            course.room_id = room_id
        if attendance_mode is not None:
            course.attendance_mode = attendance_mode
        if attendance_before_minutes is not None:
            course.attendance_before_minutes = attendance_before_minutes
        if attendance_after_minutes is not None:
            course.attendance_after_minutes = attendance_after_minutes
        await self.db.flush()
        await self.db.refresh(course)
        # Re-fetch with all eager loads for service layer properties
        res = await self.get_by_id(course.id)
        return res if res else course

    async def soft_delete(self, course: Course) -> None:
        """Soft delete by setting deleted_at."""
        from datetime import datetime, timezone
        course.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()

    async def hard_delete(self, course: Course) -> None:
        """Hard delete - use with caution."""
        await self.db.delete(course)
        await self.db.flush()

    async def count_enrolled(self, course_id: uuid.UUID) -> int:
        """Return number of students enrolled in a course."""
        from app.models.course_enrollment import CourseEnrollment
        result = await self.db.execute(
            select(sa_func.count()).select_from(CourseEnrollment).where(
                CourseEnrollment.course_id == course_id
            )
        )
        return result.scalar_one()
