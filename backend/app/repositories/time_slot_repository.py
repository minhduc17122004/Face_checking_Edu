from __future__ import annotations
"""TimeSlot repository — async DB queries for the `time_slots` table."""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.time_slot import TimeSlot
from app.repositories._base import BaseRepository


class TimeSlotRepository(BaseRepository[TimeSlot]):
    """All database interactions for TimeSlot.

    TimeSlot has no soft-delete (reference data).
    """

    model = TimeSlot

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, slot_id: int) -> TimeSlot | None:
        result = await self.db.execute(select(TimeSlot).where(TimeSlot.id == slot_id))
        return result.scalar_one_or_none()

    async def list(self, skip: int = 0, limit: int = 100) -> Sequence[TimeSlot]:
        result = await self.db.execute(
            select(TimeSlot).offset(skip).limit(limit).order_by(TimeSlot.period_number)
        )
        return result.scalars().all()
