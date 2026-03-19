from __future__ import annotations
"""v1 Devices router — /api/v1/devices endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.device_repository import DeviceRepository
from app.schemas.v1.device import DeviceCreate, DeviceUpdate, DeviceResponse
from app.schemas.v1.face import BulkAttendanceRequest

router = APIRouter(prefix="/devices", tags=["v1 — Devices"])


@router.post("/", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    req: DeviceCreate,
    db: AsyncSession = Depends(get_db),
):
    """Register a new device (no auth required — device self-registers)."""
    repo = DeviceRepository(db)
    existing = await repo.get_by_code(req.device_code)
    if existing:
        raise HTTPException(status_code=409, detail="Device code already registered.")

    from app.models.device import Device
    device = Device(
        device_code=req.device_code,
        room=req.room,
        is_active=req.is_active,
        device_type=req.device_type,
        ip_address=req.ip_address,
        classroom_id=req.classroom_id,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)


@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(
    device_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a device by ID."""
    repo = DeviceRepository(db)
    device = await repo.get_by_id(device_id)
    if not device or device.is_deleted:
        raise HTTPException(status_code=404, detail="Device not found.")
    return DeviceResponse.model_validate(device)


@router.patch("/{device_id}", response_model=DeviceResponse)
async def update_device(
    device_id: uuid.UUID,
    req: DeviceUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a device."""
    repo = DeviceRepository(db)
    device = await repo.get_by_id(device_id)
    if not device or device.is_deleted:
        raise HTTPException(status_code=404, detail="Device not found.")

    if req.room is not None:
        device.room = req.room
    if req.is_active is not None:
        device.is_active = req.is_active
    if req.device_type is not None:
        device.device_type = req.device_type
    if req.ip_address is not None:
        device.ip_address = req.ip_address
    if req.classroom_id is not None:
        device.classroom_id = req.classroom_id

    await db.flush()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)


# ── Device sync endpoints (Phase 5) ────────────────────────────────────────

@router.get("/{device_id}/sync")
async def device_sync(
    device_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/devices/{id}/sync — pull offline data for device.

    Returns enrolled students, face embeddings, and today's sessions.
    No user auth required — device authenticates via device_id.
    """
    from app.services.device_service import DeviceService
    svc = DeviceService(db)
    result = await svc.sync_data(device_id)
    await db.commit()
    return result.to_dict()


@router.post("/bulk-attendance", status_code=status.HTTP_200_OK)
async def bulk_attendance(
    req: "BulkAttendanceRequest",
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/attendance/bulk — bulk attendance from device.

    Each record is individually validated (session active, enrollment, no duplicate).
    """
    from app.services.device_service import DeviceService
    svc = DeviceService(db)
    return await svc.bulk_attendance(req)
