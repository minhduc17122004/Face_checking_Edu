from __future__ import annotations
"""Attendance service — real-time check-in and Flutter bulk-sync."""
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.attendance_repository import AttendanceRepository
from app.repositories.student_repository import StudentRepository
from app.schemas.attendance_schema import (
    CheckinRequest,
    AttendanceOut,
    AttendanceList,
    BulkSyncRequest,
    BulkSyncResponse,
    BulkSyncItemResult,
)


class AttendanceService:
    """Handles real-time check-in and offline bulk-sync from the Flutter app."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = AttendanceRepository(db)
        self.student_repo = StudentRepository(db)

    # ── REST: real-time check-in ───────────────────────────────
    async def checkin(self, req: CheckinRequest) -> AttendanceOut:
        """POST /attendance/checkin — single real-time record."""
        # Verify student exists
        student = await self.student_repo.get_by_id(req.student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {req.student_id} not found.",
            )

        record = await self.repo.create(
            student_id=req.student_id,
            class_id=req.class_id,
            record_type=req.record_type,
            checkin_time=req.checkin_time or datetime.now(timezone.utc),
            confidence=req.confidence,
            device_id=req.device_id,
            status="present",
            latitude=req.latitude,
            longitude=req.longitude,
            image_url=req.image_url,
        )
        return AttendanceOut.model_validate(record)

    # ── REST: history queries ──────────────────────────────────
    async def get_history(self, skip: int = 0, limit: int = 200) -> AttendanceList:
        records = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return AttendanceList(
            total=total,
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    async def get_by_student(
        self, student_id: int, skip: int = 0, limit: int = 200
    ) -> AttendanceList:
        records = await self.repo.get_by_student(
            student_id, skip=skip, limit=limit
        )
        return AttendanceList(
            total=len(records),
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    async def get_by_class(
        self, class_id: uuid.UUID, skip: int = 0, limit: int = 500
    ) -> AttendanceList:
        records = await self.repo.get_by_class(class_id, skip=skip, limit=limit)
        return AttendanceList(
            total=len(records),
            items=[AttendanceOut.model_validate(r) for r in records],
        )

    # ── Flutter legacy: bulk sync ──────────────────────────────
    async def bulk_sync(self, req: BulkSyncRequest) -> BulkSyncResponse:
        """POST /api/attendance/history/sync_bulk_io

        Processes a batch of offline attendance records from the Flutter app.

        For each entry:
          - Parse the device-side checkin_time from ISO string.
          - Check for duplicates (identical student_id + checkin_time + type).
          - Skip duplicates silently, record errors individually.
          - Bulk-insert all new records in a single flush.
        """
        to_create: list[dict] = []
        results: list[BulkSyncItemResult] = []
        synced = 0
        duplicates = 0
        errors = 0

        for entry in req.records:
            # Parse device timestamp
            try:
                checkin_time = datetime.fromisoformat(entry.checkTime)
                if checkin_time.tzinfo is None:
                    # Assume device sent local-naive time; treat as UTC
                    checkin_time = checkin_time.replace(tzinfo=timezone.utc)
            except ValueError:
                errors += 1
                results.append(
                    BulkSyncItemResult(
                        empId=entry.empId,
                        checkTime=entry.checkTime,
                        recordType=entry.recordType,
                        status="error",
                        message=f"Invalid datetime format: '{entry.checkTime}'",
                    )
                )
                continue

            # Duplicate check
            dup = await self.repo.find_duplicate(
                student_id=entry.empId,
                checkin_time=checkin_time,
                record_type=entry.recordType,
            )
            if dup:
                duplicates += 1
                results.append(
                    BulkSyncItemResult(
                        empId=entry.empId,
                        checkTime=entry.checkTime,
                        recordType=entry.recordType,
                        status="duplicate",
                        message="Record already synced.",
                    )
                )
                continue

            # Parse optional class_id
            class_id: uuid.UUID | None = None
            if entry.classId:
                try:
                    class_id = uuid.UUID(entry.classId)
                except ValueError:
                    class_id = None

            to_create.append(
                {
                    "student_id": entry.empId,
                    "class_id": class_id,
                    "record_type": entry.recordType,
                    "checkin_time": checkin_time,
                    "confidence": entry.confidence,
                    "device_id": entry.deviceId,
                    "status": "present",
                    "latitude": entry.latitude,
                    "longitude": entry.longitude,
                    "image_url": entry.imageUrl,
                    # Store the original entry for result mapping
                    "_orig_check_time": entry.checkTime,
                    "_orig_emp_id": entry.empId,
                    "_orig_type": entry.recordType,
                }
            )

        # Bulk insert valid new records
        if to_create:
            # Strip internal metadata keys before passing to repo
            db_data = [
                {k: v for k, v in d.items() if not k.startswith("_")}
                for d in to_create
            ]
            try:
                await self.repo.bulk_create(db_data)
                for d in to_create:
                    synced += 1
                    results.append(
                        BulkSyncItemResult(
                            empId=d["_orig_emp_id"],
                            checkTime=d["_orig_check_time"],
                            recordType=d["_orig_type"],
                            status="synced",
                        )
                    )
            except Exception as exc:
                errors += len(to_create)
                for d in to_create:
                    results.append(
                        BulkSyncItemResult(
                            empId=d["_orig_emp_id"],
                            checkTime=d["_orig_check_time"],
                            recordType=d["_orig_type"],
                            status="error",
                            message=str(exc),
                        )
                    )

        return BulkSyncResponse(
            synced=synced,
            duplicates=duplicates,
            errors=errors,
            results=results,
        )
