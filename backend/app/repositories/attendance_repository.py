from __future__ import annotations
"""Attendance repository — async DB queries for the `attendance` table (session-based)."""
import uuid
from datetime import datetime
from typing import Sequence, Optional

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base
from app.models.attendance import Attendance
from app.repositories._base import BaseRepository


class AttendanceRepository(BaseRepository[Attendance]):
    """All database interactions for Attendance (session-based unified system).

    All queries automatically exclude soft-deleted records.
    Duplicate check is enforced via UNIQUE constraint on (session_id, student_id).
    """

    model = Attendance

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────────────────────
    async def get_by_id(self, record_id: uuid.UUID) -> Attendance | None:
        result = await self.db.execute(
            select(Attendance).where(Attendance.id == record_id)
        )
        return result.scalar_one_or_none()

    async def get_by_session_student(
        self, session_id: uuid.UUID, student_id: int
    ) -> Attendance | None:
        """Check if student already has an attendance record for this session."""
        result = await self.db.execute(
            select(Attendance).where(
                and_(
                    Attendance.session_id == session_id,
                    Attendance.student_id == student_id,
                    Attendance.is_deleted == False,
                )
            )
        )
        return result.scalar_one_or_none()

    async def get_by_student(
        self, student_id: int, skip: int = 0, limit: int = 200
    ) -> Sequence[Attendance]:
        result = await self.db.execute(
            select(Attendance)
            .where(
                and_(
                    Attendance.student_id == student_id,
                    Attendance.is_deleted == False,
                )
            )
            .offset(skip)
            .limit(limit)
            .order_by(Attendance.checkin_time.desc())
        )
        return result.scalars().all()

    async def get_by_session(
        self, session_id: uuid.UUID, skip: int = 0, limit: int = 1000
    ) -> Sequence[Attendance]:
        result = await self.db.execute(
            select(Attendance)
            .where(
                and_(
                    Attendance.session_id == session_id,
                    Attendance.is_deleted == False,
                )
            )
            .offset(skip)
            .limit(limit)
            .order_by(Attendance.checkin_time.asc())
        )
        return result.scalars().all()

    async def get_all(self, skip: int = 0, limit: int = 200) -> Sequence[Attendance]:
        result = await self.db.execute(
            select(Attendance)
            .where(Attendance.is_deleted == False)
            .offset(skip)
            .limit(limit)
            .order_by(Attendance.sync_time.desc())
        )
        return result.scalars().all()

    async def count(self) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Attendance).where(Attendance.is_deleted == False)
        )
        return result.scalar_one()

    async def count_by_session(self, session_id: uuid.UUID) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Attendance).where(
                and_(
                    Attendance.session_id == session_id,
                    Attendance.is_deleted == False,
                )
            )
        )
        return result.scalar_one()

    async def count_by_status(
        self, session_id: uuid.UUID, status: str
    ) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(Attendance).where(
                and_(
                    Attendance.session_id == session_id,
                    Attendance.status == status,
                    Attendance.is_deleted == False,
                )
            )
        )
        return result.scalar_one()

    # ── Write ────────────────────────────────────────────────────────────────
    async def create(
        self,
        *,
        session_id: uuid.UUID,
        student_id: int,
        checkin_time: datetime,
        sync_time: datetime | None = None,
        status: str = "present",
        confidence: float | None = None,
        device_id: uuid.UUID | None = None,
    ) -> Attendance:
        record = Attendance(
            session_id=session_id,
            student_id=student_id,
            checkin_time=checkin_time,
            sync_time=sync_time or datetime.utcnow(),
            status=status,
            confidence=confidence,
            device_id=device_id,
        )
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return record

    async def soft_delete(self, record: Attendance) -> None:
        """Soft delete: sets is_deleted=True."""
        await super().soft_delete(record)

    async def delete(self, record: Attendance) -> None:
        """Hard delete (reserved — prefer soft_delete)."""
        await self.db.delete(record)
        await self.db.flush()
