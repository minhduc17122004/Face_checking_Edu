from __future__ import annotations
# app/models/__init__.py
# Import all models so SQLAlchemy registers them with Base.metadata.
# This is required for create_all_tables() and Alembic autogenerate.
from app.models.user import User  # noqa: F401
from app.models.teacher import Teacher  # noqa: F401
from app.models.student import Student  # noqa: F401
from app.models.classroom import Classroom  # noqa: F401
from app.models.face_embedding import FaceEmbedding  # noqa: F401
from app.models.attendance import AttendanceRecord  # noqa: F401
from app.models.device import Device  # noqa: F401

__all__ = [
    "User",
    "Teacher",
    "Student",
    "Classroom",
    "FaceEmbedding",
    "AttendanceRecord",
    "Device",
]
