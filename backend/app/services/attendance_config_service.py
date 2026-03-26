from __future__ import annotations
"""Attendance config service — per-session tolerance settings (Phase 9)."""
import uuid
from datetime import datetime

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance_config import AttendanceConfig
from app.repositories.attendance_config_repository import AttendanceConfigRepository
from app.repositories.session_repository import SessionRepository
from app.schemas.v1.attendance_config import (
    AttendanceConfigCreate,
    AttendanceConfigUpdate,
    AttendanceConfigResponse,
)


class AttendanceConfigService:
    """Manages per-session attendance tolerance configuration.

    Allows setting early_allowance and late_allowance in minutes per session.
    If no config exists, defaults (15min/15min) are used.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = AttendanceConfigRepository(db)
        self.session_repo = SessionRepository(db)

    async def get_config(self, session_id: uuid.UUID) -> AttendanceConfigResponse:
        """GET /attendance-configs/{session_id}."""
        config = await self.repo.get_by_session(session_id)
        if not config:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No attendance config found for session {session_id}.",
            )
        return AttendanceConfigResponse.model_validate(config)

    async def create_or_update(
        self, req: AttendanceConfigCreate
    ) -> AttendanceConfigResponse:
        """POST /attendance-configs — create or update config for a session."""
        # Verify session exists
        session = await self.session_repo.get_by_id(req.session_id)
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Session {req.session_id} not found.",
            )

        config = await self.repo.upsert(
            session_id=req.session_id,
            early_allowance=req.early_allowance,
            late_allowance=req.late_allowance,
        )
        await self.db.commit()
        return AttendanceConfigResponse.model_validate(config)

    async def update_config(
        self, session_id: uuid.UUID, req: AttendanceConfigUpdate
    ) -> AttendanceConfigResponse:
        """PATCH /attendance-configs/{session_id}."""
        config = await self.repo.get_by_session(session_id)
        if not config:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No attendance config found for session {session_id}.",
            )
        if req.early_allowance is not None:
            config.early_allowance = req.early_allowance
        if req.late_allowance is not None:
            config.late_allowance = req.late_allowance
        await self.db.flush()
        await self.db.commit()
        return AttendanceConfigResponse.model_validate(config)

    async def get_effective_config(
        self, session_id: uuid.UUID
    ) -> tuple[int, int]:
        """Return (early_allowance, late_allowance) for a session.

        Returns stored config or defaults (15, 15) if no config exists.
        """
        config = await self.repo.get_by_session(session_id)
        if config:
            return config.early_allowance, config.late_allowance
        return 15, 15  # defaults
