from __future__ import annotations
"""Schedule repository — async DB queries for the `schedules` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.schedule import Schedule
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
            select(Schedule).where(Schedule.id == schedule_id)
        )
        return result.scalar_one_or_none()

    async def get_by_classroom_day(
        self, classroom_id: uuid.UUID, day_of_week: int
    ) -> Sequence[Schedule]:
        result = await self.db.execute(
            select(Schedule).where(
                and_(
                    Schedule.classroom_id == classroom_id,
                    Schedule.day_of_week == day_of_week,
                    Schedule.is_deleted == False,
                )
            )
        )
        return result.scalars().all()

    async def get_by_classroom(self, classroom_id: uuid.UUID) -> Sequence[Schedule]:
        result = await self.db.execute(
            select(Schedule).where(
                and_(
                    Schedule.classroom_id == classroom_id,
                    Schedule.is_deleted == False,
                )
            )
        )
        return result.scalars().all()

    async def list(
        self,
        classroom_id: uuid.UUID | None = None,
        day_of_week: int | None = None,
        skip: int = 0,
        limit: int = 200,
    ) -> tuple[Sequence[Schedule], int]:
        conditions = [Schedule.is_deleted == False]
        if classroom_id:
            conditions.append(Schedule.classroom_id == classroom_id)
        if day_of_week is not None:
            conditions.append(Schedule.day_of_week == day_of_week)
        where_clause = and_(*conditions)
        from sqlalchemy import func
        count_result = await self.db.execute(
            select(func.count()).select_from(Schedule).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Schedule).where(where_clause).offset(skip).limit(limit)
        )
        return result.scalars().all(), total

    async def soft_delete(self, schedule: Schedule) -> None:
        await super().soft_delete(schedule)
