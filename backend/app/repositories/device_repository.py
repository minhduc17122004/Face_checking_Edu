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
            select(Device).where(Device.device_code == device_code)
        )
        return result.scalar_one_or_none()

    async def get_by_classroom(self, classroom_id: uuid.UUID) -> Sequence[Device]:
        result = await self.db.execute(
            select(Device).where(
                and_(
                    Device.classroom_id == classroom_id,
                    Device.is_deleted == False,
                )
            )
        )
        return result.scalars().all()

    async def get_active(self) -> Sequence[Device]:
        result = await self.db.execute(
            select(Device).where(Device.is_active == True, Device.is_deleted == False)  # noqa: E712
        )
        return result.scalars().all()

    async def soft_delete(self, device: Device) -> None:
        await super().soft_delete(device)
