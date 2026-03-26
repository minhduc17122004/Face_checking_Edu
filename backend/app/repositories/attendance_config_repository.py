from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Sequence, Optional

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance_config import AttendanceConfig
from app.repositories._base import BaseRepository


class AttendanceConfigRepository(BaseRepository[AttendanceConfig]):
    """All database interactions for AttendanceConfig."""

    model = AttendanceConfig

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_session(self, session_id: uuid.UUID) -> AttendanceConfig | None:
        """Get config for a specific session."""
        result = await self.db.execute(
            select(AttendanceConfig).where(
                AttendanceConfig.session_id == session_id
            )
        )
        return result.scalar_one_or_none()

    async def upsert(
        self,
        session_id: uuid.UUID,
        room_id: uuid.UUID | None = None,
        mode: str | None = None,
        early_allowance: int = 15,
        late_allowance: int = 15,
    ) -> AttendanceConfig:
        """Create or update config for a session."""
        existing = await self.get_by_session(session_id)
        if existing:
            existing.room_id = room_id
            existing.mode = mode
            existing.early_allowance = early_allowance
            existing.late_allowance = late_allowance
            await self.db.flush()
            await self.db.refresh(existing)
            return existing
        else:
            cfg = AttendanceConfig(
                session_id=session_id,
                room_id=room_id,
                mode=mode,
                early_allowance=early_allowance,
                late_allowance=late_allowance,
            )
            self.db.add(cfg)
            await self.db.flush()
            await self.db.refresh(cfg)
            return cfg
