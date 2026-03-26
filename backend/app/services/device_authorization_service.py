from __future__ import annotations
"""Device authorization service — permission and room access checks (Phase 9)."""
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.device import Device
from app.models.device_request import DeviceRequest
from app.models.session import Session


class DeviceAuthorizationService:
    """Checks device permissions for attendance operations.

    Authorization rules:
    - is_global=true  → device can attend in any room
    - is_global=false → device can only attend in its assigned room_id

    Phase 9 also checks DeviceRequest approval status.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def check_device_access(
        self,
        device_id: uuid.UUID,
        session_id: uuid.UUID,
    ) -> tuple[bool, str]:
        """Check if a device has access to take attendance for a session.

        Phase 9 rules:
        1. Device must be ACTIVE (not just is_active=True)
        2. Device must be is_global=true OR device.room_id == course.room_id
        3. Device must have an APPROVED DeviceRequest

        Returns: (is_authorized, message)
        """
        # 1. Check device exists and status
        result = await self.db.execute(
            select(Device).where(Device.id == device_id)
        )
        device = result.scalar_one_or_none()
        if not device or device.deleted_at is not None:
            return False, "Device not found"
        if device.status != "ACTIVE":
            return False, f"Device is {device.status}"
        if not device.is_active:
            return False, "Device is not active"

        # 2. Check session exists
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()
        if not session or session.deleted_at is not None:
            return False, "Session not found"

        # 3. Check global vs room scope
        if not device.is_global:
            # Device is room-scoped — verify course room matches
            from app.models.course import Course
            course_result = await self.db.execute(
                select(Course).where(Course.id == session.course_id)
            )
            course = course_result.scalar_one_or_none()
            if not course:
                return False, "Course not found"
            if device.room_id != course.room_id:
                return False, "Device room does not match course room"

        # 4. Check approved DeviceRequest exists for this device
        request_result = await self.db.execute(
            select(DeviceRequest).where(
                DeviceRequest.device_code == device.device_code,
                DeviceRequest.status == "APPROVED",
                DeviceRequest.deleted_at.is_(None),
            )
        )
        approved_request = request_result.scalar_one_or_none()
        if not approved_request:
            return False, "No approved device request found"

        # 5. Check request scope covers this room
        if approved_request.room_id is not None:
            # Request is room-scoped — verify it covers this room
            from app.models.course import Course
            course_result = await self.db.execute(
                select(Course).where(Course.id == session.course_id)
            )
            course = course_result.scalar_one_or_none()
            if course and approved_request.room_id != course.room_id:
                return False, "Device request does not cover this room"

        return True, "Authorized"

    async def update_device_status(
        self,
        device_id: uuid.UUID,
        status: str,
    ) -> Device:
        """Update device status (ACTIVE/INACTIVE)."""
        result = await self.db.execute(
            select(Device).where(Device.id == device_id)
        )
        device = result.scalar_one_or_none()
        if not device:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found",
            )
        device.status = status
        await self.db.flush()
        return device

    async def check_device_room_binding_by_code(
        self,
        device_code: str,
        room_id: uuid.UUID,
    ) -> tuple[bool, str, uuid.UUID | None]:
        """Validate device_code can submit attendance for the given room.

        Returns: (is_authorized, message, device_uuid)
        """
        result = await self.db.execute(
            select(Device).where(Device.device_code == device_code)
        )
        device = result.scalar_one_or_none()
        if not device or device.deleted_at is not None:
            return False, "Device not found", None
        if device.status != "ACTIVE" or not device.is_active:
            return False, "Device is inactive", None

        # Room scope validation.
        if not device.is_global and device.room_id != room_id:
            return False, "Device room does not match payload room", None

        request_result = await self.db.execute(
            select(DeviceRequest).where(
                DeviceRequest.device_code == device.device_code,
                DeviceRequest.status == "APPROVED",
                DeviceRequest.deleted_at.is_(None),
            )
        )
        approved_request = request_result.scalar_one_or_none()
        if not approved_request:
            return False, "No approved device request found", None
        if approved_request.room_id is not None and approved_request.room_id != room_id:
            return False, "Device request does not cover this room", None

        return True, "Authorized", device.id
