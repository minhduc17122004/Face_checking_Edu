from __future__ import annotations
"""Teacher repository — async DB queries for the `teachers` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.teacher import Teacher


class TeacherRepository:
    """All database interactions for Teacher."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, teacher_id: int) -> Teacher | None:
        result = await self.db.execute(
            select(Teacher).where(
                and_(
                    Teacher.id == teacher_id,
                    Teacher.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_user_id(self, user_id: uuid.UUID) -> Teacher | None:
        result = await self.db.execute(
            select(Teacher).where(
                and_(
                    Teacher.user_id == user_id,
                    Teacher.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def list(self, skip: int = 0, limit: int = 200) -> tuple[Sequence[Teacher], int]:
        conditions = [Teacher.deleted_at.is_(None)]
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Teacher).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Teacher)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(Teacher.created_at.desc())
        )
        return result.scalars().all(), total

    async def get_by_department(
        self,
        department_id: uuid.UUID,
        skip: int = 0,
        limit: int = 200,
    ) -> tuple[Sequence[Teacher], int]:
        conditions = [
            Teacher.department_id == department_id,
            Teacher.deleted_at.is_(None),
        ]
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Teacher).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Teacher)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
        )
        return result.scalars().all(), total

    async def assign_department(
        self,
        teacher: Teacher,
        department_id: uuid.UUID,
    ) -> Teacher:
        teacher.department_id = department_id
        await self.db.flush()
        await self.db.refresh(teacher)
        return teacher

    async def remove_department(self, teacher: Teacher) -> Teacher:
        teacher.department_id = None
        await self.db.flush()
        await self.db.refresh(teacher)
        return teacher

    async def soft_delete(self, teacher: Teacher) -> None:
        from datetime import datetime, timezone
        teacher.deleted_at = datetime.now(timezone.utc)
        await self.db.flush()
