from __future__ import annotations
"""AcademicClass repository — async DB queries for the `academic_classes` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.academic_class import AcademicClass
from app.repositories._base import BaseRepository


class AcademicClassRepository(BaseRepository[AcademicClass]):
    """All database interactions for AcademicClass.

    All queries automatically exclude soft-deleted records.
    """

    model = AcademicClass

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, class_id: uuid.UUID) -> AcademicClass | None:
        result = await self.db.execute(
            select(AcademicClass).where(AcademicClass.id == class_id)
        )
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> AcademicClass | None:
        result = await self.db.execute(
            select(AcademicClass).where(AcademicClass.code == code)
        )
        return result.scalar_one_or_none()

    async def list(
        self,
        code: str | None = None,
        faculty: str | None = None,
        course_year: str | None = None,
        skip: int = 0,
        limit: int = 200,
    ) -> tuple[Sequence[AcademicClass], int]:
        conditions = [AcademicClass.is_deleted == False]
        if code:
            conditions.append(AcademicClass.code.ilike(f"%{code}%"))
        if faculty:
            conditions.append(AcademicClass.faculty.ilike(f"%{faculty}%"))
        if course_year:
            conditions.append(AcademicClass.course_year == course_year)
        where_clause = and_(*conditions)
        from sqlalchemy import func
        count_result = await self.db.execute(
            select(func.count()).select_from(AcademicClass).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(AcademicClass)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(AcademicClass.code)
        )
        return result.scalars().all(), total

    async def soft_delete(self, academic_class: AcademicClass) -> None:
        await super().soft_delete(academic_class)
