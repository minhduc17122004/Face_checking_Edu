from __future__ import annotations
"""Room repository — async DB queries for the `rooms` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.room import Room
from app.repositories._base import BaseRepository


class RoomRepository(BaseRepository[Room]):
    """All database interactions for Room.

    All queries automatically exclude soft-deleted records.
    """

    model = Room

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, room_id: uuid.UUID) -> Room | None:
        result = await self.db.execute(select(Room).where(Room.id == room_id))
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> Room | None:
        result = await self.db.execute(
            select(Room).where(
                and_(
                    Room.code == code,
                    Room.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_name(self, name: str) -> Room | None:
        result = await self.db.execute(
            select(Room).where(
                and_(
                    Room.name == name,
                    Room.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_max_sequential_code(self) -> int:
        result = await self.db.execute(
            select(Room.code)
        )
        codes = [c for c in result.scalars().all() if c and c.isdigit()]
        if not codes:
            return 0
        return max(int(c) for c in codes)

    async def list_active(
        self, skip: int = 0, limit: int = 200
    ) -> tuple[Sequence[Room], int]:
        """Return active rooms with total count."""
        conditions = [Room.deleted_at.is_(None)]
        where_clause = and_(*conditions)
        count_result = await self.db.execute(
            select(func.count()).select_from(Room).where(where_clause)
        )
        total = count_result.scalar_one()
        result = await self.db.execute(
            select(Room)
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(Room.code.asc())
        )
        return result.scalars().all(), total

    async def count_courses(self, room_id: uuid.UUID) -> int:
        """Return number of active courses assigned to this room."""
        result = await self.db.execute(
            select(func.count()).select_from(Room).where(
                and_(
                    Room.id == room_id,
                    Room.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one()

    async def soft_delete(self, room: Room) -> None:
        await super().soft_delete(room)
