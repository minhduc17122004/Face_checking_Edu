from __future__ import annotations
# app/repositories/__init__.py
# Re-export all repository classes for convenient service-layer imports.

from app.repositories.user_repository import UserRepository  # noqa: F401
from app.repositories.student_repository import StudentRepository  # noqa: F401
from app.repositories.classroom_repository import ClassroomRepository  # noqa: F401
from app.repositories.attendance_repository import AttendanceRepository  # noqa: F401
from app.repositories.face_repository import FaceRepository  # noqa: F401

__all__ = [
    "UserRepository",
    "StudentRepository",
    "ClassroomRepository",
    "AttendanceRepository",
    "FaceRepository",
]
