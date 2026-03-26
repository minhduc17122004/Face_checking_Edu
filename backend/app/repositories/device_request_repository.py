from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Sequence, Optional

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.models.device_request import DeviceRequest
from app.repositories._base import BaseRepository


class DeviceRequestRepository(BaseRepository[DeviceRequest]):
    """All database interactions for DeviceRequest."""

    model = DeviceRequest

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, request_id: uuid.UUID
    ) -> DeviceRequest | None:
        result = await self.db.execute(
            select(DeviceRequest)
            .options(
                joinedload(DeviceRequest.room),
                joinedload(DeviceRequest.requester),
                joinedload(DeviceRequest.reviewer),
            )
            .where(DeviceRequest.id == request_id)
        )
        return result.scalar_one_or_none()

    async def get_by_device_code(
        self, device_code: str
    ) -> Sequence[DeviceRequest]:
        result = await self.db.execute(
            select(DeviceRequest)
            .options(
                joinedload(DeviceRequest.room),
                joinedload(DeviceRequest.requester),
            )
            .where(
                and_(
                    DeviceRequest.device_code == device_code,
                    DeviceRequest.deleted_at.is_(None),
                )
            )
            .order_by(DeviceRequest.created_at.desc())
        )
        return result.scalars().all()

    async def get_pending(self) -> Sequence[DeviceRequest]:
        result = await self.db.execute(
            select(DeviceRequest)
            .options(
                joinedload(DeviceRequest.room),
                joinedload(DeviceRequest.requester),
            )
            .where(
                and_(
                    DeviceRequest.status == "PENDING",
                    DeviceRequest.deleted_at.is_(None),
                )
            )
            .order_by(DeviceRequest.created_at.desc())
        )
        return result.scalars().all()

    async def list_all(
        self,
        status: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[Sequence[DeviceRequest], int]:
        conditions = [DeviceRequest.deleted_at.is_(None)]
        if status:
            conditions.append(DeviceRequest.status == status)
        where_clause = and_(*conditions)

        count_result = await self.db.execute(
            select(func.count()).select_from(DeviceRequest).where(where_clause)
        )
        total = count_result.scalar_one()

        result = await self.db.execute(
            select(DeviceRequest)
            .options(
                joinedload(DeviceRequest.room),
                joinedload(DeviceRequest.requester),
                joinedload(DeviceRequest.reviewer),
            )
            .where(where_clause)
            .offset(skip)
            .limit(limit)
            .order_by(DeviceRequest.created_at.desc())
        )
        return result.unique().scalars().all(), total

    async def create(
        self,
        device_code: str,
        device_name: str | None = None,
        room_id: uuid.UUID | None = None,
        requested_by: uuid.UUID | None = None,
    ) -> DeviceRequest:
        request = DeviceRequest(
            device_code=device_code,
            device_name=device_name,
            room_id=room_id,
            requested_by=requested_by,
            status="PENDING",
        )
        self.db.add(request)
        await self.db.flush()
        # Fetch back with relationships for the response
        return await self.get_by_id(request.id)  # type: ignore[return-value]

    async def approve(
        self,
        request: DeviceRequest,
        reviewed_by: uuid.UUID,
        admin_note: str | None = None,
    ) -> DeviceRequest:
        request.status = "APPROVED"
        request.reviewed_by = reviewed_by
        request.reviewed_at = datetime.now(timezone.utc)
        request.admin_note = admin_note
        await self.db.flush()
        await self.db.refresh(request)
        return request

    async def reject(
        self,
        request: DeviceRequest,
        reviewed_by: uuid.UUID,
        admin_note: str | None = None,
    ) -> DeviceRequest:
        request.status = "REJECTED"
        request.reviewed_by = reviewed_by
        request.reviewed_at = datetime.now(timezone.utc)
        request.admin_note = admin_note
        await self.db.flush()
        await self.db.refresh(request)
        return request

    async def soft_delete(self, request: DeviceRequest) -> None:
        await super().soft_delete(request)
