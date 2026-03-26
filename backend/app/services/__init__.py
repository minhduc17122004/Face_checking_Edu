from __future__ import annotations
# app/services/__init__.py
# Re-export all service classes for clean router imports.

from app.services._base import BaseService  # noqa: F401
from app.services.auth_service import AuthService  # noqa: F401
from app.services.user_service import UserService  # noqa: F401
from app.services.student_service import StudentService  # noqa: F401
from app.services.course_service import CourseService  # noqa: F401
from app.services.attendance_service import AttendanceService  # noqa: F401
from app.services.face_service import FaceService  # noqa: F401
from app.services.anti_cheat_service import AntiCheatService  # noqa: F401
from app.services.device_service import DeviceService  # noqa: F401
from app.services.device_request_service import DeviceRequestService  # noqa: F401
from app.services.device_authorization_service import DeviceAuthorizationService  # noqa: F401
from app.services.audit_service import AuditService  # noqa: F401
from app.services.department_service import DepartmentService  # noqa: F401
from app.services.teacher_service import TeacherService  # noqa: F401
from app.services.session_generator_service import SessionGeneratorService  # noqa: F401
from app.services.attendance_validator import AttendanceValidator  # noqa: F401
from app.services.room_service import RoomService  # noqa: F401
from app.services.attendance_config_service import AttendanceConfigService  # noqa: F401

__all__ = [
    "AntiCheatService",
    "AttendanceConfigService",
    "AttendanceService",
    "AttendanceValidator",
    "AuditService",
    "AuthService",
    "BaseService",
    "CourseService",
    "DepartmentService",
    "DeviceAuthorizationService",
    "DeviceRequestService",
    "DeviceService",
    "FaceService",
    "SessionGeneratorService",
    "StudentService",
    "TeacherService",
    "UserService",
    "RoomService",
]

# Aliases for backward compatibility
# DEPRECATED: Use new names
ClassroomService = CourseService
