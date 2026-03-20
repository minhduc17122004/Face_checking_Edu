from __future__ import annotations
"""Course repository — async DB queries for the `courses` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, func as sa_func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course import Course


class CourseRepository:
    """All database interactions for the Course model."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, course_id: uuid.UUID) -> Course | None:
        result = await self.db.execute(
            select(Course).where(
                Course.id == course_id,
                Course.deleted_at.is_(None),
            )
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 200) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .where(Course.deleted_at.is_(None))
            .offset(skip)
            .limit(limit)
            .order_by(Course.created_at.desc())
        )
        return result.scalars().all()

    async def get_by_instructor(
        self, instructor_id: uuid.UUID
    ) -> Sequence[Course]:
        result = await self.db.execute(
            select(Course)
            .where(
                Course.instructor_id == instructor_id,
                Course.deleted_at.is_(None),
            )
            .order_by(Course.created_at.desc())
        )
        return result.scalars().all()

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
            .where(
                Course.course_name.ilike(f"%{name}%"),
                Course.deleted_at.is_(None),
            )
            .order_by(Course.course_name)
            .limit(50)
        )
        return result.scalars().all()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        course_name: str,
        instructor_id: uuid.UUID | None = None,
        subject: str | None = None,
        course_code: str | None = None,
    ) -> Course:
        course = Course(
            course_name=course_name,
            instructor_id=instructor_id,
            subject=subject,
            course_code=course_code,
        )
        self.db.add(course)
        await self.db.flush()
        await self.db.refresh(course)
        return course

    async def update(
        self,
        course: Course,
        *,
        course_name: str | None = None,
        subject: str | None = None,
        course_code: str | None = None,
    ) -> Course:
        if course_name is not None:
            course.course_name = course_name
        if subject is not None:
            course.subject = subject
        if course_code is not None:
            course.course_code = course_code
        await self.db.flush()
        await self.db.refresh(course)
        return course

    async def soft_delete(self, course: Course) -> None:
        """Soft delete by setting deleted_at."""
        from datetime import datetime, timezone
        course.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()

    async def hard_delete(self, course: Course) -> None:
        """Hard delete - use with caution."""
        await self.db.delete(course)
        await self.db.flush()
