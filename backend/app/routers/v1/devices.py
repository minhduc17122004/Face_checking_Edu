from __future__ import annotations
"""v1 Devices router — /api/v1/devices endpoints."""
import uuid
import hmac
import hashlib
import time as time_module

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.repositories.device_repository import DeviceRepository
from app.schemas.v1.device import DeviceCreate, DeviceUpdate, DeviceResponse
from app.schemas.v1.face import BulkAttendanceRequest
from app.schemas.v1.room import AssignRoomRequest

router = APIRouter(prefix="/devices", tags=["v1 — Devices"])


async def verify_device_signature(request: Request) -> uuid.UUID:
    """Verify device signature from request headers.

    Validates: X-Device-Signature header using HMAC-SHA256.
    Timestamp must be within 5 minutes to prevent replay attacks.
    """
    signature = request.headers.get("X-Device-Signature")
    timestamp_str = request.headers.get("X-Device-Timestamp")
    device_id_str = request.headers.get("X-Device-ID")

    if not signature or not timestamp_str or not device_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing device authentication headers.",
        )

    # Verify timestamp is within 5 minutes
    try:
        ts = int(timestamp_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid timestamp format.",
        )

    current_time = int(time_module.time())
    if abs(current_time - ts) > 300:  # 5 minutes
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Device signature expired.",
        )

    # Look up device secret from database
    from app.core.database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        repo = DeviceRepository(session)
        device = await repo.get_by_id(uuid.UUID(device_id_str))
        if not device:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Device not found.",
            )

        # Verify HMAC signature using device secret
        # NOTE: In production, device_secret should be stored hashed or as a raw key
        # Here we use device_code as the shared secret (replace with device.secret in prod)
        message = f"{device_id_str}:{timestamp_str}"
        expected_signature = hmac.new(
            device.device_code.encode(),
            message.encode(),
            hashlib.sha256,
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_signature):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid device signature.",
            )

    return uuid.UUID(device_id_str)


@router.post("/", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
async def register_device(
    req: DeviceCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Register a new device (admin only)."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    repo = DeviceRepository(db)
    existing = await repo.get_by_code(req.device_code)
    if existing:
        raise HTTPException(status_code=409, detail="Device code already registered.")

    from app.models.device import Device
    device = Device(
        device_code=req.device_code,
        room_id=req.room_id,
        is_active=req.is_active,
        is_global=req.is_global,
        status="ACTIVE",
        device_type=req.device_type,
        ip_address=req.ip_address,
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

    if req.room_id is not None:
        device.room_id = req.room_id
    if req.is_active is not None:
        device.is_active = req.is_active
    if req.is_global is not None:
        device.is_global = req.is_global
    if req.status is not None:
        device.status = req.status
    if req.device_type is not None:
        device.device_type = req.device_type
    if req.ip_address is not None:
        device.ip_address = req.ip_address

    await db.flush()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)


@router.put("/{device_id}/assign-room", response_model=DeviceResponse)
async def assign_device_room(
    device_id: uuid.UUID,
    req: AssignRoomRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Assign a room to a device."""
    repo = DeviceRepository(db)
    device = await repo.get_by_id(device_id)
    if not device or device.is_deleted:
        raise HTTPException(status_code=404, detail="Device not found.")

    from app.services.room_service import RoomService
    room_svc = RoomService(db)
    # Validate room exists (raises 404 if not found)
    await room_svc.get_room(req.room_id)

    device.room_id = req.room_id
    await db.commit()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)


# ── Device sync endpoints (Phase 5 / Phase 7 security) ──────────────────────

@router.get("/{device_id}/sync")
async def device_sync(
    device_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/devices/{id}/sync — pull offline data for device.

    Returns enrolled students, face embeddings, and today's sessions.
    Device authenticates via X-Device-Signature header.
    """
    # Verify device signature
    await verify_device_signature(request)

    from app.services.device_service import DeviceService
    svc = DeviceService(db)
    result = await svc.sync_data(device_id)
    await db.commit()
    return result.to_dict()


@router.post("/bulk-attendance", status_code=status.HTTP_200_OK)
async def bulk_attendance(
    req: "BulkAttendanceRequest",
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/attendance/bulk — bulk attendance from device.

    Each record is individually validated (session active, enrollment, no duplicate).
    Device authenticates via X-Device-Signature header.
    """
    # Verify device signature
    await verify_device_signature(request)

    from app.services.device_service import DeviceService
    svc = DeviceService(db)
    return await svc.bulk_attendance(req)
