from __future__ import annotations
# app/repositories/__init__.py
# Re-export all repository classes for convenient service-layer imports.

from app.repositories._base import BaseRepository  # noqa: F401
from app.repositories.user_repository import UserRepository  # noqa: F401
from app.repositories.student_repository import StudentRepository  # noqa: F401
from app.repositories.classroom_repository import ClassroomRepository  # noqa: F401
from app.repositories.attendance_repository import AttendanceRepository  # noqa: F401
from app.repositories.face_repository import FaceRepository  # noqa: F401
from app.repositories.session_repository import SessionRepository  # noqa: F401
from app.repositories.schedule_repository import ScheduleRepository  # noqa: F401
from app.repositories.time_slot_repository import TimeSlotRepository  # noqa: F401
from app.repositories.classroom_student_repository import ClassroomStudentRepository  # noqa: F401
from app.repositories.academic_class_repository import AcademicClassRepository  # noqa: F401
from app.repositories.device_repository import DeviceRepository  # noqa: F401

__all__ = [
    "BaseRepository",
    "UserRepository",
    "StudentRepository",
    "ClassroomRepository",
    "AttendanceRepository",
    "FaceRepository",
    "SessionRepository",
    "ScheduleRepository",
    "TimeSlotRepository",
    "ClassroomStudentRepository",
    "AcademicClassRepository",
    "DeviceRepository",
]
