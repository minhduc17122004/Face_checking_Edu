from __future__ import annotations

from fastapi import APIRouter

from app.routers.v1.auth import router as auth_router
from app.routers.v1.users import router as users_router
from app.routers.v1.students import router as students_router
from app.routers.v1.classrooms import router as classrooms_router
from app.routers.v1.attendance import router as attendance_router
from app.routers.v1.devices import router as devices_router
from app.routers.v1.sessions import router as sessions_router
from app.routers.v1.schedules import router as schedules_router
from app.routers.v1.time_slots import router as time_slots_router
from app.routers.v1.classroom_students import router as classroom_students_router
from app.routers.v1.academic_classes import router as academic_classes_router
from app.routers.v1.faces import router as faces_router

api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(auth_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(students_router)
api_v1_router.include_router(classrooms_router)
api_v1_router.include_router(attendance_router)
api_v1_router.include_router(devices_router)
api_v1_router.include_router(sessions_router)
api_v1_router.include_router(schedules_router)
api_v1_router.include_router(time_slots_router)
api_v1_router.include_router(classroom_students_router)
api_v1_router.include_router(academic_classes_router)
api_v1_router.include_router(faces_router)

__all__ = [
    "api_v1_router",
    "auth_router",
    "users_router",
    "students_router",
    "classrooms_router",
    "attendance_router",
    "devices_router",
    "sessions_router",
    "schedules_router",
    "time_slots_router",
    "classroom_students_router",
    "academic_classes_router",
    "faces_router",
]
