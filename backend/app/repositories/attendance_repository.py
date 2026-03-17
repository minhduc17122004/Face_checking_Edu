from __future__ import annotations
"""Attendance repository — raw async DB queries for `attendance_records`."""
import uuid
from datetime import datetime
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import AttendanceRecord


class AttendanceRepository:
    """All database interactions for AttendanceRecord.

    Bulk-sync deduplication logic lives here so the service layer
    only needs to handle business decisions (e.g. skip vs reject).
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, record_id: uuid.UUID) -> AttendanceRecord | None:
        result = await self.db.execute(
            select(AttendanceRecord).where(AttendanceRecord.id == record_id)
        )
        return result.scalar_one_or_none()

    async def get_by_student(
        self, student_id: int, skip: int = 0, limit: int = 200
    ) -> Sequence[AttendanceRecord]:
        result = await self.db.execute(
            select(AttendanceRecord)
            .where(AttendanceRecord.student_id == student_id)
            .offset(skip)
            .limit(limit)
            .order_by(AttendanceRecord.checkin_time.desc())
        )
        return result.scalars().all()

    async def get_by_class(
        self, class_id: uuid.UUID, skip: int = 0, limit: int = 500
    ) -> Sequence[AttendanceRecord]:
        result = await self.db.execute(
            select(AttendanceRecord)
            .where(AttendanceRecord.class_id == class_id)
            .offset(skip)
            .limit(limit)
            .order_by(AttendanceRecord.checkin_time.desc())
        )
        return result.scalars().all()

    async def get_all(self, skip: int = 0, limit: int = 200) -> Sequence[AttendanceRecord]:
        result = await self.db.execute(
            select(AttendanceRecord)
            .offset(skip)
            .limit(limit)
            .order_by(AttendanceRecord.sync_time.desc())
        )
        return result.scalars().all()

    async def count(self) -> int:
        from sqlalchemy import func as sa_func
        result = await self.db.execute(
            select(sa_func.count()).select_from(AttendanceRecord)
        )
        return result.scalar_one()

    async def find_duplicate(
        self,
        student_id: int,
        checkin_time: datetime,
        record_type: str,
    ) -> AttendanceRecord | None:
        """Check if an identical offline record was already synced.

        Duplicates are detected by matching (student_id, checkin_time, record_type).
        A tolerance of ±1 second is NOT applied here — exact match only.
        """
        result = await self.db.execute(
            select(AttendanceRecord).where(
                and_(
                    AttendanceRecord.student_id == student_id,
                    AttendanceRecord.checkin_time == checkin_time,
                    AttendanceRecord.record_type == record_type,
                )
            )
        )
        return result.scalar_one_or_none()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        student_id: int,
        class_id: uuid.UUID | None = None,
        record_type: str = "checkin",
        checkin_time: datetime | None = None,
        confidence: float | None = None,
        device_id: str | None = None,
        status: str = "present",
        latitude: float | None = None,
        longitude: float | None = None,
        image_url: str | None = None,
    ) -> AttendanceRecord:
        record = AttendanceRecord(
            student_id=student_id,
            class_id=class_id,
            record_type=record_type,
            checkin_time=checkin_time,
            confidence=confidence,
            device_id=device_id,
            status=status,
            latitude=latitude,
            longitude=longitude,
            image_url=image_url,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return record

    async def bulk_create(
        self, records_data: list[dict]
    ) -> list[AttendanceRecord]:
        """Insert many records in one flush for bulk-sync performance."""
        created: list[AttendanceRecord] = []
        for data in records_data:
            r = AttendanceRecord(**data)
            self.db.add(r)
            created.append(r)
        await self.db.flush()
        for r in created:
            await self.db.refresh(r)
        return created

    async def delete(self, record: AttendanceRecord) -> None:
        await self.db.delete(record)
        await self.db.flush()
