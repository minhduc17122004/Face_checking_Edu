from __future__ import annotations
"""Student service — CRUD and Flutter-compatible student operations."""
import os
import uuid as _uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.repositories.student_repository import StudentRepository
from app.schemas.student_schema import (
    StudentCreate,
    StudentOut,
    StudentList,
    StudentOutLegacy,
    StudentCreateLegacy,
    BatchCreateResponse,
    GetAllStudentsResponse,
    AvatarUploadFile,
    AvatarUploadResponse,
)


class StudentService:
    """Handles student CRUD and all Flutter legacy student operations."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = StudentRepository(db)

    # ── REST API operations ────────────────────────────────────
    async def create_student(self, req: StudentCreate) -> StudentOut:
        student = await self.repo.create(
            name=req.name,
            pin=req.pin,
            job_title=req.job_title,
            has_avatar=req.has_avatar,
            attachment_id=req.attachment_id,
        )
        return StudentOut.model_validate(student)

    async def get_student(self, student_id: int) -> StudentOut:
        student = await self.repo.get_by_id(student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )
        return StudentOut.model_validate(student)

    async def list_students(self, skip: int = 0, limit: int = 500) -> StudentList:
        students = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return StudentList(
            total=total,
            items=[StudentOut.model_validate(s) for s in students],
        )

    # ── Flutter legacy operations ──────────────────────────────
    async def get_all_students(self) -> GetAllStudentsResponse:
        """GET /api/student/get_all_students — Flutter-compatible list."""
        students = await self.repo.get_all(limit=10_000)
        students_out = [StudentOutLegacy.from_student(s) for s in students]
        return GetAllStudentsResponse.build(students_out)

    async def create_student_legacy(self, data: StudentCreateLegacy) -> StudentOutLegacy:
        """POST /api/student/create — single student via legacy endpoint."""
        student = await self.repo.create(
            name=data.name,
            pin=data.pin,
            job_title=data.jobTitle,
            has_avatar=data.hasAvatar,
            attachment_id=data.attachmentId,
        )
        return StudentOutLegacy.from_student(student)

    async def batch_create_students(
        self, students_data: list[StudentCreateLegacy]
    ) -> BatchCreateResponse:
        """POST /api/student/create/batch — batch student creation."""
        created_list: list[StudentOutLegacy] = []
        failed = 0

        students_to_create = [
            {
                "name": s.name,
                "pin": s.pin,
                "job_title": s.jobTitle,
                "has_avatar": s.hasAvatar,
                "attachment_id": s.attachmentId,
            }
            for s in students_data
        ]
        try:
            created = await self.repo.bulk_create(students_to_create)
            created_list = [StudentOutLegacy.from_student(s) for s in created]
        except Exception:
            failed = len(students_data)

        return BatchCreateResponse(
            created=len(created_list),
            failed=failed,
            students=created_list,
        )

    async def upload_avatars(
        self,
        files: list[UploadFile],
        student_ids: list[int],
    ) -> AvatarUploadResponse:
        """POST /api/student/avatars/upload — save avatar images, update records."""
        upload_dir = Path(settings.UPLOAD_DIR) / "avatars"
        upload_dir.mkdir(parents=True, exist_ok=True)

        upload_id = str(_uuid.uuid4())
        result_files: list[AvatarUploadFile] = []

        for file, student_id in zip(files, student_ids):
            student = await self.repo.get_by_id(student_id)
            if not student:
                continue  # skip unknown student silently

            # Save file with a stable name: <studentId>_<original_filename>
            suffix = Path(file.filename or "avatar.jpg").suffix
            dest_name = f"{student_id}{suffix}"
            dest_path = upload_dir / dest_name

            content = await file.read()
            dest_path.write_bytes(content)

            url = f"/{settings.UPLOAD_DIR}/avatars/{dest_name}"
            await self.repo.update_avatar(student, avatar_url=url, has_avatar=True)

            result_files.append(
                AvatarUploadFile(studentId=student_id, fileName=dest_name, url=url)
            )

        return AvatarUploadResponse(
            data=AvatarUploadResponse._Data(
                uploadId=upload_id,
                files=result_files,
            )
        )
