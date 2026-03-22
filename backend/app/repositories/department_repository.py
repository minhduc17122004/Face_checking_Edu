from __future__ import annotations
"""Department repository — async DB queries for the `departments` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.department import Department


class DepartmentRepository:
    """All database interactions for Department."""

    model = Department

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, department_id: uuid.UUID) -> Department | None:
        result = await self.db.execute(
            select(Department).where(
                and_(
                    Department.id == department_id,
                    Department.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> Department | None:
        result = await self.db.execute(
            select(Department).where(
                and_(
                    Department.code == code,
                    Department.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def list(
        self,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[Sequence[Department], int]:
        conditions = [Department.deleted_at.is_(None)]
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Department).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Department)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(Department.name)
        )
        return result.scalars().all(), total

    async def count_teachers(self, department_id: uuid.UUID) -> int:
        from app.models.teacher import Teacher
        result = await self.db.execute(
            select(func.count())
            .select_from(Teacher)
            .where(
                and_(
                    Teacher.department_id == department_id,
                    Teacher.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one()

    async def count_courses(self, department_id: uuid.UUID) -> int:
        from app.models.course import Course
        result = await self.db.execute(
            select(func.count())
            .select_from(Course)
            .where(
                and_(
                    Course.department_id == department_id,
                    Course.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one()

    async def create(
        self,
        *,
        code: str,
        name: str,
    ) -> Department:
        department = Department(
            code=code,
            name=name,
        )
        self.db.add(department)
        await self.db.flush()
        await self.db.refresh(department)
        return department

    async def update(
        self,
        department: Department,
        *,
        code: str | None = None,
        name: str | None = None,
    ) -> Department:
        if code is not None:
            department.code = code
        if name is not None:
            department.name = name
        await self.db.flush()
        await self.db.refresh(department)
        return department

    async def soft_delete(self, department: Department) -> None:
        from datetime import datetime, timezone
        department.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
