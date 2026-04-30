from __future__ import annotations
"""Schedule repository — async DB queries for the `schedules` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.orm import joinedload, selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.schedule import Schedule
from app.models.course import Course
from app.models.course_enrollment import CourseEnrollment
from app.repositories._base import BaseRepository


class ScheduleRepository(BaseRepository[Schedule]):
    """All database interactions for Schedule.

    All queries automatically exclude soft-deleted records.
    """

    model = Schedule

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, schedule_id: uuid.UUID) -> Schedule | None:
        result = await self.db.execute(
            select(Schedule)
            .options(
                joinedload(Schedule.time_slot),
                joinedload(Schedule.end_time_slot),
                joinedload(Schedule.course),
            )
            .where(Schedule.id == schedule_id)
        )
        return result.scalar_one_or_none()

    async def get_by_course_day(
        self, course_id: uuid.UUID, day_of_week: int
    ) -> Sequence[Schedule]:
        result = await self.db.execute(
            select(Schedule)
            .options(
                joinedload(Schedule.time_slot),
                joinedload(Schedule.end_time_slot),
                joinedload(Schedule.course),
            )
            .where(
                and_(
                    Schedule.course_id == course_id,
                    Schedule.day_of_week == day_of_week,
                    Schedule.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def get_by_course(self, course_id: uuid.UUID) -> Sequence[Schedule]:
        result = await self.db.execute(
            select(Schedule)
            .options(
                joinedload(Schedule.time_slot),
                joinedload(Schedule.end_time_slot),
                joinedload(Schedule.course),
            )
            .where(
                and_(
                    Schedule.course_id == course_id,
                    Schedule.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def list(
        self,
        course_id: uuid.UUID | None = None,
        day_of_week: int | None = None,
        skip: int = 0,
        limit: int = 200,
        teacher_id: int | None = None,
        student_id: int | None = None,
    ) -> tuple[Sequence[Schedule], int]:
        conditions = [Schedule.deleted_at.is_(None)]
        if teacher_id is not None:
            conditions.append(Schedule.course.has(Course.teacher_id == teacher_id))
        if student_id is not None:
            conditions.append(Schedule.course.has(Course.enrollments.any(CourseEnrollment.student_id == student_id)))
        if course_id:
            conditions.append(Schedule.course_id == course_id)
        if day_of_week is not None:
            conditions.append(Schedule.day_of_week == day_of_week)
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Schedule).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Schedule)
            .options(
                joinedload(Schedule.time_slot),
                joinedload(Schedule.end_time_slot),
                joinedload(Schedule.course),
            )
            .where(where_clause)
            .offset(skip)
            .limit(limit)
        )
        return result.scalars().all(), total

    async def soft_delete(self, schedule: Schedule) -> None:
        await super().soft_delete(schedule)

    async def update(
        self,
        schedule: Schedule,
        *,
        day_of_week: int | None = None,
        time_slot_id: int | None = None,
        end_time_slot_id: int | None = None,
    ) -> Schedule:
        if day_of_week is not None:
            schedule.day_of_week = day_of_week
        if time_slot_id is not None:
            schedule.time_slot_id = time_slot_id
        if end_time_slot_id is not None:
            schedule.end_time_slot_id = end_time_slot_id
        await self.db.flush()
        await self.db.refresh(schedule)
        return schedule
