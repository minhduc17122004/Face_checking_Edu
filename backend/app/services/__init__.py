from __future__ import annotations
# app/services/__init__.py
# Re-export all service classes for clean router imports.

from app.services._base import BaseService  # noqa: F401
from app.services.auth_service import AuthService  # noqa: F401
from app.services.user_service import UserService  # noqa: F401
from app.services.student_service import StudentService  # noqa: F401
from app.services.classroom_service import ClassroomService  # noqa: F401
from app.services.attendance_service import AttendanceService  # noqa: F401
from app.services.face_service import FaceService  # noqa: F401
from app.services.anti_cheat_service import AntiCheatService  # noqa: F401
from app.services.device_service import DeviceService  # noqa: F401
from app.services.audit_service import AuditService  # noqa: F401

__all__ = [
    "BaseService",
    "AuthService",
    "UserService",
    "StudentService",
    "ClassroomService",
    "AttendanceService",
    "FaceService",
    "AntiCheatService",
    "DeviceService",
    "AuditService",
]
