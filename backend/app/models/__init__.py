from __future__ import annotations

# Core model base (must be imported first)
from app.core.database import Base  # noqa: F401

# Mixins
from app.models._mixins import SoftDeleteMixin, AuditMixin  # noqa: F401

# Models
from app.models.user import User  # noqa: F401
from app.models.teacher import Teacher  # noqa: F401
from app.models.student import Student  # noqa: F401
from app.models.classroom import Classroom  # noqa: F401
from app.models.face_embedding import FaceEmbedding  # noqa: F401
from app.models.device import Device  # noqa: F401
from app.models.time_slot import TimeSlot  # noqa: F401
from app.models.classroom_student import ClassroomStudent  # noqa: F401
from app.models.schedule import Schedule  # noqa: F401
from app.models.session import Session  # noqa: F401
from app.models.attendance import Attendance  # noqa: F401
from app.models.academic_class import AcademicClass  # noqa: F401
from app.models.refresh_token import RefreshToken  # noqa: F401

__all__ = [
    # Base
    "Base",
    # Mixins
    "SoftDeleteMixin",
    "AuditMixin",
    # Models
    "User",
    "Teacher",
    "Student",
    "Classroom",
    "FaceEmbedding",
    "Device",
    "TimeSlot",
    "ClassroomStudent",
    "Schedule",
    "Session",
    "Attendance",
    "AcademicClass",
    "RefreshToken",
]
