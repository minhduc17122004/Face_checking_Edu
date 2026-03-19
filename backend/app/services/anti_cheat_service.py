from __future__ import annotations
"""Anti-cheat service for attendance validation."""
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.device import Device
from app.models.session import Session
from app.models.attendance import Attendance


class AntiCheatService:
    """Validates attendance against anti-cheat rules.

    All methods return tuple[bool, str] where:
    - bool: True = valid/pass, False = invalid/fail
    - str: "OK" on pass, human-readable error message on fail
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def validate_session_exists(
        self, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Verify session exists, is not deleted, and has a valid status."""
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"
        if session.is_deleted:
            return False, "Session has been cancelled"
        return True, "OK"

    async def validate_device_for_session(
        self, device_id: uuid.UUID, session_id: uuid.UUID
    ) -> tuple[bool, str]:
        """Verify device belongs to the same classroom as session.

        Returns:
            tuple[bool, str]: (is_valid, message)
        """
        # Get device's classroom
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        device = result.scalar_one_or_none()

        if not device:
            return False, "Device not found"

        if device.is_deleted:
            return False, "Device has been deactivated"

        if not device.is_active:
            return False, "Device is not active"

        # Get session's classroom
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"

        if session.is_deleted:
            return False, "Session has been cancelled"

        # Verify device belongs to session's classroom
        if device.classroom_id != session.classroom_id:
            return False, "Device not registered for this classroom"

        return True, "OK"

    async def validate_checkin_window(
        self, session_id: uuid.UUID, checkin_time: datetime
    ) -> tuple[bool, str]:
        """Check if checkin is within allowed window.

        Returns:
            tuple[bool, str]: (is_valid, message)
        """
        result = await self.db.execute(
            select(Session).where(Session.id == session_id)
        )
        session = result.scalar_one_or_none()

        if not session:
            return False, "Session not found"

        # Session must be active to accept attendance
        if session.status != "active":
            return False, f"Session is not active (current status: {session.status})"

        # Check checkin_start_time
        if session.checkin_start_time and checkin_time < session.checkin_start_time:
            return False, "Check-in not allowed yet"

        # Check checkin_end_time
        if session.checkin_end_time and checkin_time > session.checkin_end_time:
            return False, "Check-in window has closed"

        return True, "OK"

    async def detect_duplicate_attendance(
        self,
        session_id: uuid.UUID,
        student_id: int,
        exclude_id: Optional[uuid.UUID] = None,
    ) -> tuple[bool, str]:
        """Check if student has already been marked present in this session.

        Returns:
            tuple[bool, str]: (has_duplicate, message)
        """
        query = select(Attendance).where(
            Attendance.session_id == session_id,
            Attendance.student_id == student_id,
            Attendance.is_deleted == False,
        )

        result = await self.db.execute(query)
        existing = result.scalar_one_or_none()

        if existing and (exclude_id is None or existing.id != exclude_id):
            return True, f"Student {student_id} already has attendance in this session"

        return False, "OK"

    async def update_device_last_active(
        self, device_id: uuid.UUID
    ) -> None:
        """Update device last_active_at timestamp."""
        result = await self.db.execute(select(Device).where(Device.id == device_id))
        device = result.scalar_one_or_none()

        if device:
            device.last_active_at = datetime.now(timezone.utc)
            await self.db.commit()
