from __future__ import annotations
"""Audit logging service — structured event logging for compliance and debugging."""
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

# Dedicated audit logger — writes to app_log.audit channel
audit_logger = logging.getLogger("audit")


class AuditService:
    """Structured audit event logger.

    All events are emitted via the 'audit' logger at INFO level with structured
    extra fields for searchable log aggregation (e.g. ELK / Datadog).

    Usage:
        svc = AuditService()
        svc.log_attendance_created(attendance_id, student_id, session_id, device_id)
    """

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    def _emit(self, event: str, **extra: Any) -> None:
        audit_logger.info(event, extra={"event": event, **extra})

    # ── Attendance ───────────────────────────────────────────────────────────
    def log_attendance_created(
        self,
        attendance_id: uuid.UUID,
        student_id: int,
        session_id: uuid.UUID,
        device_id: uuid.UUID | None = None,
        status: str = "present",
    ) -> None:
        self._emit(
            "attendance_created",
            attendance_id=str(attendance_id),
            student_id=student_id,
            session_id=str(session_id),
            device_id=str(device_id) if device_id else None,
            status=status,
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
