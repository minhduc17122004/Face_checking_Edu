from __future__ import annotations
"""StudentGroup repository — async DB queries for the `student_groups` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.student_group import StudentGroup
from app.repositories._base import BaseRepository


class StudentGroupRepository(BaseRepository[StudentGroup]):
    """All database interactions for StudentGroup.

    All queries automatically exclude soft-deleted records.
    """

    model = StudentGroup

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, group_id: uuid.UUID) -> StudentGroup | None:
        result = await self.db.execute(
            select(StudentGroup).where(StudentGroup.id == group_id)
        )
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> StudentGroup | None:
        result = await self.db.execute(
            select(StudentGroup).where(StudentGroup.code == code)
        )
        return result.scalar_one_or_none()

    async def list(
        self,
        code: str | None = None,
        faculty: str | None = None,
        course_year: str | None = None,
        skip: int = 0,
        limit: int = 200,
    ) -> tuple[Sequence[StudentGroup], int]:
        conditions = [StudentGroup.deleted_at.is_(None)]
        if code:
            conditions.append(StudentGroup.code.ilike(f"%{code}%"))
        if faculty:
            conditions.append(StudentGroup.faculty.ilike(f"%{faculty}%"))
        if course_year:
            conditions.append(StudentGroup.course_year == course_year)
        where_clause = and_(*conditions)

        count_result = await self.db.execute(
            select(func.count()).select_from(StudentGroup).where(where_clause)
        )
        total = count_result.scalar_one()

        result = await self.db.execute(
            select(StudentGroup)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(StudentGroup.code)
        )
        return result.scalars().all(), total

    async def get_by_advisor(self, advisor_id: uuid.UUID) -> Sequence[StudentGroup]:
        result = await self.db.execute(
            select(StudentGroup)
            .where(
                StudentGroup.advisor_id == advisor_id,
                StudentGroup.deleted_at.is_(None),
            )
            .order_by(StudentGroup.code)
        )
        return result.scalars().all()

    async def soft_delete(self, student_group: StudentGroup) -> None:
        await super().soft_delete(student_group)
