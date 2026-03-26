from __future__ import annotations
"""v1 Attendance Configs router — /api/v1/attendance-configs endpoints (Phase 9)."""
import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.attendance_config_service import AttendanceConfigService
from app.schemas.v1.attendance_config import (
    AttendanceConfigCreate,
    AttendanceConfigUpdate,
    AttendanceConfigResponse,
)

router = APIRouter(prefix="/attendance-configs", tags=["v1 — Attendance Configs"])


@router.post(
    "/",
    response_model=AttendanceConfigResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_attendance_config(
    req: AttendanceConfigCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/attendance-configs — create per-session attendance config.

    Sets early/late allowance in minutes for a specific session.
    Creates or updates (upsert) the config.
    """
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = AttendanceConfigService(db)
    return await svc.create_or_update(req)


@router.get("/{session_id}", response_model=AttendanceConfigResponse)
async def get_attendance_config(
    session_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/attendance-configs/{session_id} — get config for a session."""
    svc = AttendanceConfigService(db)
    return await svc.get_config(session_id)


@router.patch("/{session_id}", response_model=AttendanceConfigResponse)
async def update_attendance_config(
    session_id: uuid.UUID,
    req: AttendanceConfigUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /api/v1/attendance-configs/{session_id} — update config."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = AttendanceConfigService(db)
    return await svc.update_config(session_id, req)
