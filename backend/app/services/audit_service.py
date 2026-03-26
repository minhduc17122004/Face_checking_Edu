from __future__ import annotations
"""Audit logging service — structured event logging for compliance and debugging."""
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy.ext.asyncio import AsyncSession

# Dedicated audit logger — writes to app_log.audit channel
audit_logger = logging.getLogger("audit")


class AuditService:
    """Structured audit event logger.

    All events are emitted via the 'audit' logger at INFO level with structured
    extra fields for searchable log aggregation (e.g. ELK / Datadog).

    Phase 9: Can also write to the attendance_audit_logs DB table when a
    db session is provided.

    Usage:
        svc = AuditService(db)          # DB-backed (preferred for attendance)
        svc = AuditService()            # Logger-only (fallback)
        svc.log_attendance_created(...)
    """

    def __init__(self, db: Optional[AsyncSession] = None) -> None:
        self._db = db

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    def _emit(self, event: str, **extra: Any) -> None:
        audit_logger.info(event, extra={"event": event, **extra})

    # ── Attendance DB write (Phase 9) ─────────────────────────────────────────
    async def write_attendance_audit(
        self,
        student_id: int,
        session_id: uuid.UUID,
        action: str,
        new_status: Optional[str] = None,
        old_status: Optional[str] = None,
        device_id: uuid.UUID | None = None,
        minutes_diff: int | None = None,
    ) -> None:
        """Write an attendance audit record to the DB table."""
        if not self._db:
            return
        from app.models.attendance_audit_log import AttendanceAuditLog
        record = AttendanceAuditLog(
            student_id=student_id,
            session_id=session_id,
            action=action,
            old_status=old_status,
            new_status=new_status,
            device_id=device_id,
            minutes_diff=minutes_diff,
        )
        self._db.add(record)
        await self._db.flush()

    # ── Attendance ───────────────────────────────────────────────────────────
    def log_attendance_created(
        self,
        attendance_id: uuid.UUID,
        student_id: int,
        session_id: uuid.UUID,
        device_id: uuid.UUID | None = None,
        status: str = "present",
        minutes_diff: int | None = None,
    ) -> None:
        self._emit(
            "attendance_created",
            attendance_id=str(attendance_id),
            student_id=student_id,
            session_id=str(session_id),
            device_id=str(device_id) if device_id else None,
            status=status,
            minutes_diff=minutes_diff,
        )

    def log_attendance_deleted(
        self,
        attendance_id: uuid.UUID,
        deleted_by: str,
    ) -> None:
        self._emit(
            "attendance_deleted",
            attendance_id=str(attendance_id),
            deleted_by=deleted_by,
        )

    def log_duplicate_attendance_attempt(
        self,
        student_id: int,
        session_id: uuid.UUID,
        device_id: uuid.UUID | None = None,
    ) -> None:
        self._emit(
            "duplicate_attendance_attempt",
            student_id=student_id,
            session_id=str(session_id),
            device_id=str(device_id) if device_id else None,
        )

    # ── Face embeddings ─────────────────────────────────────────────────────
    def log_face_registered(
        self,
        student_id: int,
        embedding_id: uuid.UUID,
        embedding_count_after: int,
        device_id: uuid.UUID | None = None,
    ) -> None:
        self._emit(
            "face_registered",
            student_id=student_id,
            embedding_id=str(embedding_id),
            embedding_count_after=embedding_count_after,
            device_id=str(device_id) if device_id else None,
        )

    def log_face_evicted(
        self,
        student_id: int,
        evicted_embedding_id: uuid.UUID,
        reason: str = "fifo_max_reached",
    ) -> None:
        self._emit(
            "face_evicted",
            student_id=student_id,
            evicted_embedding_id=str(evicted_embedding_id),
            reason=reason,
        )

    # ── Device sync ──────────────────────────────────────────────────────────
    def log_device_sync(
        self,
        device_id: uuid.UUID,
        student_count: int,
        embedding_count: int,
        session_count: int,
        direction: str,  # "pull" | "push"
    ) -> None:
        self._emit(
            "device_sync",
            device_id=str(device_id),
            student_count=student_count,
            embedding_count=embedding_count,
            session_count=session_count,
            direction=direction,
        )

    def log_bulk_attendance(
        self,
        device_id: uuid.UUID | None,
        total_records: int,
        synced: int,
        duplicates: int,
        errors: int,
    ) -> None:
        self._emit(
            "bulk_attendance",
            device_id=str(device_id) if device_id else None,
            total_records=total_records,
            synced=synced,
            duplicates=duplicates,
            errors=errors,
        )

    # ── Auth ─────────────────────────────────────────────────────────────────
    def log_login(self, user_id: str, device_id: uuid.UUID | None = None) -> None:
        self._emit("login", user_id=user_id, device_id=str(device_id) if device_id else None)

    def log_logout(self, user_id: str) -> None:
        self._emit("logout", user_id=user_id)

    def log_token_refresh(self, user_id: str) -> None:
        self._emit("token_refresh", user_id=user_id)
