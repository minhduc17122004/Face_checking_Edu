from __future__ import annotations
"""v1 Device Requests router — /api/v1/device-requests endpoints (Phase 9)."""
import uuid

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.device_request_service import DeviceRequestService
from app.schemas.v1.device_request import (
    DeviceRequestSubmit,
    ApproveRequest,
    RejectRequest,
    DeviceRequestResponse,
    DeviceRequestList,
)

router = APIRouter(prefix="/device-requests", tags=["v1 — Device Requests"])


@router.post(
    "/",
    response_model=DeviceRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_device_request(
    req: DeviceRequestSubmit,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """POST /api/v1/device-requests — submit a device permission request.

    Any authenticated user (teacher/tablet) can submit a request.
    Admin must approve/reject via admin endpoints.
    """
    svc = DeviceRequestService(db)
    result = await svc.submit_request(
        req,
        user_id=uuid.UUID(user_id) if user_id else None,
    )
    await db.commit()
    return result


@router.get("/me", response_model=DeviceRequestList)
async def get_my_device_requests(
    device_code: str = Query(..., description="Device code to check requests for"),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/device-requests/me — get requests for current device.

    No auth required — device identifies itself by code.
    """
    svc = DeviceRequestService(db)
    return await svc.get_my_requests(device_code)


# ── Admin endpoints ──────────────────────────────────────────────────────

@router.get("/", response_model=DeviceRequestList)
async def list_device_requests(
    req_status: str | None = Query(None, alias="status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/device-requests — list all requests (admin only)."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = DeviceRequestService(db)
    return await svc.list_requests(status=req_status, skip=skip, limit=limit)


@router.get("/{request_id}", response_model=DeviceRequestResponse)
async def get_device_request(
    request_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """GET /api/v1/device-requests/{id}."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = DeviceRequestService(db)
    return await svc.get_request(request_id)


@router.patch("/{request_id}/approve", response_model=DeviceRequestResponse)
async def approve_device_request(
    request_id: uuid.UUID,
    req: ApproveRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /api/v1/device-requests/{id}/approve — approve a request (admin)."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = DeviceRequestService(db)
    return await svc.approve_request(
        request_id,
        admin_id=uuid.UUID(user_id),
        req=req,
    )


@router.patch("/{request_id}/reject", response_model=DeviceRequestResponse)
async def reject_device_request(
    request_id: uuid.UUID,
    req: RejectRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """PATCH /api/v1/device-requests/{id}/reject — reject a request (admin)."""
    from app.core.rbac import require_role
    await require_role("admin")(user_id)

    svc = DeviceRequestService(db)
    return await svc.reject_request(
        request_id,
        admin_id=uuid.UUID(user_id),
        req=req,
    )
