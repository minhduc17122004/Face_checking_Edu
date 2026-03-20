from __future__ import annotations
"""Legacy router — Flutter-compatible API endpoints under /api/.

These endpoints implement the exact URL paths and JSON response shapes
that the Flutter app's `ApiEndpoint` constants reference, allowing the
mobile app to work without any code changes.

Flutter endpoint constants (from api_endpoint.dart):
    GET  /api/student/get_all_students
    GET  /api/student/export/json
    PUT  /api/student/update/embedding
    POST /api/student/create
    POST /api/student/create/batch
    POST /api/student/avatars/upload
    POST /api/attendance/history/sync_bulk_io
"""
from typing import List, Any

from fastapi import APIRouter, Depends, File, Form, UploadFile, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.student_schema import (
    StudentCreateLegacy,
    StudentOutLegacy,
    BatchCreateRequest,
    BatchCreateResponse,
    GetAllStudentsResponse,
    AvatarUploadResponse,
)
from app.schemas.face_schema import FaceDataOut
from app.schemas.attendance_schema import BulkSyncRequest, BulkSyncResponse
from app.services.student_service import StudentService
from app.services.face_service import FaceService
from app.services.attendance_service import AttendanceService

router = APIRouter(prefix="/api", tags=["Flutter Legacy API"])


# ── Student endpoints ──────────────────────────────────────────────

@router.get(
    "/student/get_all_students",
    response_model=GetAllStudentsResponse,
    summary="[Flutter] Get all students",
)
async def get_all_students(
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> GetAllStudentsResponse:
    """Returns `{ "data": { "students": [...] } }` exactly as Flutter expects."""
    return await StudentService(db).get_all_students()


@router.post(
    "/student/create",
    response_model=StudentOutLegacy,
    status_code=201,
    summary="[Flutter] Create a single student",
)
async def create_student(
    body: StudentCreateLegacy,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentOutLegacy:
    """Create a single student via the legacy Flutter contract."""
    return await StudentService(db).create_student_legacy(body)


@router.post(
    "/student/create/batch",
    response_model=BatchCreateResponse,
    status_code=201,
    summary="[Flutter] Batch create students",
)
async def batch_create_students(
    body: BatchCreateRequest,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> BatchCreateResponse:
    """Create multiple students in a single call."""
    return await StudentService(db).batch_create_students(body.students)


@router.post(
    "/student/avatars/upload",
    response_model=AvatarUploadResponse,
    summary="[Flutter] Upload avatar images for students",
)
async def upload_avatars(
    files: List[UploadFile] = File(...),
    student_ids: List[int] = Form(...),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AvatarUploadResponse:
    """Upload avatar images. `files` and `student_ids` must be parallel arrays
    (files[i] belongs to student_ids[i]).
    """
    return await StudentService(db).upload_avatars(files=files, student_ids=student_ids)


# ── Face embedding endpoints ───────────────────────────────────────────────────

@router.get(
    "/student/export/json",
    response_model=List[FaceDataOut],
    summary="[Flutter] Export all face embeddings as JSON",
)
async def export_face_embeddings(
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> list[FaceDataOut]:
    """Returns `[{ "studentId": 1, "listFaceEmbedding": [[...]], "updatedTime": "..." }]`
    for ALL students. The Flutter app pulls this on startup to load its local
    face recognition engine.
    """
    return await FaceService(db).export_all()


@router.put(
    "/student/update/embedding",
    summary="[Flutter] Push updated face embeddings via .json file upload",
)
async def update_face_embedding(
    file: UploadFile = File(..., description="A .json file with the embedding payload."),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Accepts a `.json` file upload containing the full embedding dataset.
    For each student entry, atomically replaces their stored embeddings.

    Returns `{ "updated": N, "skipped": N, "errors": N }`.
    """
    return await FaceService(db).import_from_file(file)


# ── Attendance bulk sync ───────────────────────────────────────────────────────

@router.post(
    "/attendance/history/sync_bulk_io",
    response_model=BulkSyncResponse,
    summary="[Flutter] Bulk sync offline attendance records",
)
async def sync_bulk_attendance(
    body: BulkSyncRequest,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> BulkSyncResponse:
    """Sync a batch of offline attendance records captured on the device.

    Returns per-record status: `synced | duplicate | error`.
    """
    return await AttendanceService(db).bulk_sync(body)


# ── Client Error Logging ───────────────────────────────────────────────────────

@router.post(
    "/log/error",
    summary="[Flutter] Log client errors to backend",
)
async def log_client_error(
    payload: dict = Body(...),
    # Optional auth if you don't require token for logging
) -> dict:
    """Accepts error logs from the Flutter application and logs them."""
    # In a real app, you might save this to a file, Sentry, or DB
    import logging
    logger = logging.getLogger("flutter_client")
    logger.error(f"Client error reported: {payload}")
    return {"status": "ok", "message": "Log recorded"}
