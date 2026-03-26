from __future__ import annotations
"""Device repository — async DB queries for the `devices` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device import Device
from app.repositories._base import BaseRepository


class DeviceRepository(BaseRepository[Device]):
    """All database interactions for Device.

    All queries automatically exclude soft-deleted records.
    """

    model = Device

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, device_id: uuid.UUID) -> Device | None:
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        return result.scalar_one_or_none()

    async def get_by_code(self, device_code: str) -> Device | None:
        result = await self.db.execute(
            select(Device).where(
                and_(
                    Device.device_code == device_code,
                    Device.deleted_at.is_(None),
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_room(self, room_id: uuid.UUID) -> Sequence[Device]:
        result = await self.db.execute(
            select(Device).where(
                and_(
                    Device.room_id == room_id,
                    Device.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def get_active(self) -> Sequence[Device]:
        result = await self.db.execute(
            select(Device).where(
                and_(
                    Device.is_active == True,
                    Device.deleted_at.is_(None),
                )
            )
        )
        return result.scalars().all()

    async def get_by_room_or_global(self, room_id: uuid.UUID) -> Sequence[Device]:
        """Get devices that have access to a specific room.

        Phase 9: is_global=true → access all rooms.
        is_global=false → must match room_id.
        """
        result = await self.db.execute(
            select(Device).where(
                and_(
                    Device.deleted_at.is_(None),
                    Device.is_active == True,
                    (Device.room_id == room_id) | (Device.is_global == True),
                )
            )
        )
        return result.scalars().all()

    async def soft_delete(self, device: Device) -> None:
        await super().soft_delete(device)
