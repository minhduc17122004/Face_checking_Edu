from __future__ import annotations
"""Device sync service — data pull and bulk attendance push for offline devices."""
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.device_repository import DeviceRepository
from app.repositories.classroom_repository import ClassroomRepository
from app.repositories.session_repository import SessionRepository
from app.repositories.classroom_student_repository import ClassroomStudentRepository
from app.repositories.face_repository import FaceRepository
from app.repositories.attendance_repository import AttendanceRepository
from app.services.face_service import FaceService
from app.services.attendance_service import AttendanceService
from app.services.audit_service import AuditService
from app.schemas.v1.face import (
    BulkAttendanceRequest,
    BulkAttendanceResponse,
    BulkResultItem,
)


class DeviceSyncResponse:
    """Container for device sync data payload."""

    def __init__(
        self,
        students: list,
        embeddings: list,
        sessions: list,
        last_sync_at: datetime,
    ) -> None:
        self.students = students
        self.embeddings = embeddings
        self.sessions = sessions
        self.last_sync_at = last_sync_at

    def to_dict(self) -> dict:
        return {
            "students": self.students,
            "embeddings": self.embeddings,
            "sessions": self.sessions,
            "last_sync_at": self.last_sync_at.isoformat(),
        }


class DeviceService:
    """Device data synchronization — offline-first attendance flow.

    sync_data():  Pull all data needed for a device to run offline
                 (enrolled students, face embeddings, today's sessions).
    bulk_attendance(): Receive batch attendance records from device,
                 validate each with anti-cheat, persist to DB.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.device_repo = DeviceRepository(db)
        self.classroom_repo = ClassroomRepository(db)
        self.session_repo = SessionRepository(db)
        self.cs_repo = ClassroomStudentRepository(db)
        self.face_repo = FaceRepository(db)
        self.face_svc = FaceService(db)
        self.att_svc = AttendanceService(db)
        self.audit = AuditService()

    # ── Sync pull ────────────────────────────────────────────────────────────
    async def sync_data(self, device_id: uuid.UUID) -> DeviceSyncResponse:
        """GET /api/v1/devices/{id}/sync — pull all offline data for a device.

        Returns:
        - students: enrolled in device's classroom
        - embeddings: active face embeddings for those students
        - sessions: today's sessions for device's classroom
        """
        device = await self.device_repo.get_by_id(device_id)
        if not device or device.is_deleted or not device.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Device is not valid or not active.",
            )

        if not device.classroom_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Device is not assigned to a classroom.",
            )

        classroom = await self.classroom_repo.get_by_id(device.classroom_id)
        if not classroom or classroom.is_deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device's classroom not found.",
            )

        # 1. Enrolled students
        enrollments = await self.cs_repo.get_by_classroom(device.classroom_id)
        student_ids = [e.student_id for e in enrollments]

        # 2. Today's sessions
        today = datetime.now(timezone.utc).date()
        sessions = await self.session_repo.get_by_classroom(
            device.classroom_id,
            session_date=today,
        )

        # 3. Face embeddings for enrolled students
        face_export = await self.face_svc.export_for_classroom(device.classroom_id)

        # Update device last sync
        device.last_sync_at = datetime.now(timezone.utc)
        await self.db.flush()

        self.audit.log_device_sync(
            device_id=device_id,
            student_count=len(student_ids),
            embedding_count=len(face_export.students),
            session_count=len(sessions),
            direction="pull",
        )

        return DeviceSyncResponse(
            students=[{"id": sid} for sid in student_ids],
            embeddings=face_export.model_dump()["students"],
            sessions=[{"id": str(s.id), "status": s.status} for s in sessions],
            last_sync_at=datetime.now(timezone.utc),
        )

    # ── Bulk push ─────────────────────────────────────────────────────────────
    async def bulk_attendance(
        self,
        req: BulkAttendanceRequest,
    ) -> BulkAttendanceResponse:
        """POST /api/v1/attendance/bulk — bulk attendance from device.

        Validates each record individually:
        - Device must be active
        - Session must exist and be active
        - Student must be enrolled
        - Anti-cheat: no duplicate check-in
        """
        if req.device_id:
            device = await self.device_repo.get_by_id(req.device_id)
            if not device or device.is_deleted or not device.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Device is not valid or not active.",
                )
        else:
            device = None

        synced = 0
        duplicates = 0
        errors = 0
        results: list[BulkResultItem] = []

        for record in req.records:
            try:
                result = await self.att_svc.create_attendance(
                    session_id=record.session_id,
                    student_id=record.student_id,
                    checkin_time=record.checkin_time,
                    status=record.status,
                    confidence=record.confidence,
                    device_id=req.device_id,
                )
                synced += 1
                results.append(
                    BulkResultItem(
                        session_id=record.session_id,
                        student_id=record.student_id,
                        checkin_time=record.checkin_time,
                        status="synced",
                        message=None,
                    )
                )
            except ValueError as exc:
                err_msg = str(exc)
                if "already checked" in err_msg or "already exists" in err_msg.lower():
                    duplicates += 1
                    results.append(
                        BulkResultItem(
                            session_id=record.session_id,
                            student_id=record.student_id,
                            checkin_time=record.checkin_time,
                            status="duplicate",
                            message=err_msg,
                        )
                    )
                else:
                    errors += 1
                    results.append(
                        BulkResultItem(
                            session_id=record.session_id,
                            student_id=record.student_id,
                            checkin_time=record.checkin_time,
                            status="error",
                            message=err_msg,
                        )
                    )
            except Exception as exc:
                errors += 1
                results.append(
                    BulkResultItem(
                        session_id=record.session_id,
                        student_id=record.student_id,
                        checkin_time=record.checkin_time,
                        status="error",
                        message=str(exc),
                    )
                )

        await self.db.commit()

        self.audit.log_bulk_attendance(
            device_id=req.device_id,
            total_records=len(req.records),
            synced=synced,
            duplicates=duplicates,
            errors=errors,
        )

        return BulkAttendanceResponse(
            synced=synced,
            duplicates=duplicates,
            errors=errors,
            results=results,
        )
