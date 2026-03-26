from __future__ import annotations
# app/repositories/__init__.py
# Re-export all repository classes for convenient service-layer imports.

from app.repositories._base import BaseRepository  # noqa: F401
from app.repositories.user_repository import UserRepository  # noqa: F401
from app.repositories.student_repository import StudentRepository  # noqa: F401
from app.repositories.attendance_repository import AttendanceRepository  # noqa: F401
from app.repositories.attendance_config_repository import AttendanceConfigRepository  # noqa: F401
from app.repositories.face_repository import FaceRepository  # noqa: F401
from app.repositories.session_repository import SessionRepository  # noqa: F401
from app.repositories.schedule_repository import ScheduleRepository  # noqa: F401
from app.repositories.time_slot_repository import TimeSlotRepository  # noqa: F401
from app.repositories.course_repository import CourseRepository  # noqa: F401
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository  # noqa: F401
from app.repositories.student_group_repository import StudentGroupRepository  # noqa: F401
from app.repositories.device_repository import DeviceRepository  # noqa: F401
from app.repositories.device_request_repository import DeviceRequestRepository  # noqa: F401
from app.repositories.department_repository import DepartmentRepository  # noqa: F401
from app.repositories.teacher_repository import TeacherRepository  # noqa: F401
from app.repositories.room_repository import RoomRepository  # noqa: F401

__all__ = [
    "AttendanceConfigRepository",
    "AttendanceRepository",
    "BaseRepository",
    "CourseEnrollmentRepository",
    "CourseRepository",
    "DepartmentRepository",
    "DeviceRepository",
    "DeviceRequestRepository",
    "FaceRepository",
    "ScheduleRepository",
    "SessionRepository",
    "StudentGroupRepository",
    "StudentRepository",
    "TeacherRepository",
    "TimeSlotRepository",
    "UserRepository",
    "RoomRepository",
]

# Aliases for backward compatibility
# DEPRECATED: Use new names
ClassroomRepository = CourseRepository
ClassroomStudentRepository = CourseEnrollmentRepository
AcademicClassRepository = StudentGroupRepository
