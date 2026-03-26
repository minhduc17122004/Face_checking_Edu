from __future__ import annotations
"""Device request service — tablet/admin permission approval flow (Phase 9)."""
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device_request import DeviceRequest
from app.repositories.device_request_repository import DeviceRequestRepository
from app.schemas.v1.device_request import (
    DeviceRequestSubmit,
    ApproveRequest,
    RejectRequest,
    DeviceRequestResponse,
    DeviceRequestList,
)


class DeviceRequestService:
    """Manages device permission requests and approvals.

    Flow:
    1. Device/tablet submits request (PENDING)
    2. Admin reviews and approves/rejects
    3. Approved → device can do attendance in scoped room(s)
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = DeviceRequestRepository(db)

    def _to_response(self, req: DeviceRequest) -> DeviceRequestResponse:
        """Convert model to response with optional joined data."""
        return DeviceRequestResponse(
            id=req.id,
            device_code=req.device_code,
            device_name=req.device_name,
            room_id=req.room_id,
            room_name=req.room.name if req.room else None,
            requested_by=req.requested_by,
            requester_name=req.requester.full_name if req.requester else None,
            status=req.status,  # type: ignore[arg-type]
            reviewed_by=req.reviewed_by,
            reviewer_name=req.reviewer.full_name if req.reviewer else None,
            reviewed_at=req.reviewed_at,
            admin_note=req.admin_note,
            created_at=req.created_at,
        )

    async def submit_request(
        self, req: DeviceRequestSubmit, user_id: uuid.UUID | None = None
    ) -> DeviceRequestResponse:
        """POST /device-requests — submit a new device permission request."""
        # Check for existing pending request for this device
        existing_requests = await self.repo.get_by_device_code(req.device_code)
        pending = [r for r in existing_requests if r.status == "PENDING"]
        if pending:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="A pending request already exists for this device. Please wait for admin approval.",
            )

        record = await self.repo.create(
            device_code=req.device_code,
            device_name=req.device_name,
            room_id=req.room_id,
            requested_by=user_id,
        )
        await self.db.commit()
        return self._to_response(record)

    async def list_requests(
        self,
        status: str | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> DeviceRequestList:
        """GET /device-requests — list all requests (admin)."""
        records, total = await self.repo.list_all(
            status=status, skip=skip, limit=limit
        )
        return DeviceRequestList(
            total=total,
            items=[self._to_response(r) for r in records],
        )

    async def get_request(self, request_id: uuid.UUID) -> DeviceRequestResponse:
        """GET /device-requests/{id}."""
        record = await self.repo.get_by_id(request_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Device request {request_id} not found.",
            )
        return self._to_response(record)

    async def approve_request(
        self, request_id: uuid.UUID, admin_id: uuid.UUID, req: ApproveRequest
    ) -> DeviceRequestResponse:
        """PATCH /device-requests/{id}/approve — approve request (admin).

        Phase 10: On approval, auto-creates or updates the Device record
        with the room_id from the request (or is_global=True if no room).
        """
        record = await self.repo.get_by_id(request_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Device request {request_id} not found.",
            )
        if record.status != "PENDING":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Request is already {record.status}.",
            )
        await self.repo.approve(
            request=record,
            reviewed_by=admin_id,
            admin_note=req.admin_note,
        )

        # Auto-create or update Device record on approval
        from app.repositories.device_repository import DeviceRepository
        device_repo = DeviceRepository(self.db)
        device = await device_repo.get_by_code(record.device_code)
        if device:
            # Update existing device with new room
            if record.room_id:
                device.room_id = record.room_id
                device.is_global = False
            else:
                device.is_global = True
            device.is_active = True
            device.device_name = record.device_name or device.device_name
            await self.db.flush()
        else:
            # Create new device
            from app.models.device import Device
            new_device = Device(
                device_code=record.device_code,
                device_name=record.device_name,
                room_id=record.room_id,
                is_global=record.room_id is None,
                is_active=True,
            )
            self.db.add(new_device)
            await self.db.flush()

        await self.db.commit()
        
        # Cleanup: Reject any other pending requests for the same device code
        try:
            other_pending = await self.repo.get_by_device_code(record.device_code)
            for other in other_pending:
                if other.id != record.id and other.status == "PENDING":
                    other.status = "REJECTED"
                    other.reviewed_by = admin_id
                    other.reviewed_at = datetime.now(timezone.utc)
                    other.admin_note = f"Auto-rejected because request {record.id} was approved."
            await self.db.commit()
        except Exception:
            # Don't fail the main operation if cleanup fails
            pass

        return self._to_response(record)

    async def reject_request(
        self, request_id: uuid.UUID, admin_id: uuid.UUID, req: RejectRequest
    ) -> DeviceRequestResponse:
        """PATCH /device-requests/{id}/reject — reject request (admin)."""
        record = await self.repo.get_by_id(request_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Device request {request_id} not found.",
            )
        if record.status != "PENDING":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Request is already {record.status}.",
            )
        await self.repo.reject(
            request=record,
            reviewed_by=admin_id,
            admin_note=req.admin_note,
        )
        await self.db.commit()
        return self._to_response(record)

    async def get_my_requests(
        self, device_code: str
    ) -> DeviceRequestList:
        """GET /device-requests/me — get requests for current device."""
        records = await self.repo.get_by_device_code(device_code)
        return DeviceRequestList(
            total=len(records),
            items=[self._to_response(r) for r in records],
        )
