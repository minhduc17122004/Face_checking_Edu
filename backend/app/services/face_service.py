"""Face service — embedding registration, REST queries, and Flutter export/import."""
import json
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.face_repository import FaceRepository
from app.repositories.student_repository import StudentRepository
from app.schemas.face_schema import (
    FaceRegisterRequest,
    FaceEmbeddingOut,
    FaceEmbeddingList,
    FaceDataOut,
)


class FaceService:
    """Business logic for face embedding management.

    Supports:
    - REST: per-student register, retrieve
    - Flutter legacy: full export (GET) and file-based import (PUT)
    """

    def __init__(self, db: AsyncSession) -> None:
        self.repo = FaceRepository(db)
        self.student_repo = StudentRepository(db)

    # ── REST operations ────────────────────────────────────────
    async def register(self, req: FaceRegisterRequest) -> FaceEmbeddingList:
        """POST /face/register — store one or more embedding vectors."""
        student = await self.student_repo.get_by_id(req.student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {req.student_id} not found.",
            )

        vectors = req.resolved_embeddings()
        if not vectors:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Either 'embedding' or 'embeddings' must be provided.",
            )

        # Atomic replace — treat each register call as an authoritative update
        embeddings = await self.repo.replace_for_student(
            student_id=req.student_id,
            embeddings=vectors,
        )
        return FaceEmbeddingList(
            student_id=req.student_id,
            count=len(embeddings),
            embeddings=[FaceEmbeddingOut.model_validate(e) for e in embeddings],
        )

    async def get_embeddings(self, student_id: int) -> FaceEmbeddingList:
        """GET /face/student/{student_id}."""
        student = await self.student_repo.get_by_id(student_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )

        embeddings = await self.repo.get_by_student(student_id)
        return FaceEmbeddingList(
            student_id=student_id,
            count=len(embeddings),
            embeddings=[FaceEmbeddingOut.model_validate(e) for e in embeddings],
        )

    # ── Flutter legacy: export ─────────────────────────────────
    async def export_all(self) -> list[FaceDataOut]:
        """GET /api/employee/export/json

        Returns all students' embeddings in Flutter's expected format:
        [ { "empId": 1, "listFaceEmbedding": [[...], ...], "updatedTime": "..." }, ... ]
        """
        all_embeddings = await self.repo.get_all()
        if not all_embeddings:
            return []

        # Group by student_id, preserving latest updated_at per student
        from collections import defaultdict
        grouped: dict = defaultdict(list)
        latest_updated: dict = {}

        for emb in all_embeddings:
            grouped[emb.student_id].append(emb)
            if (
                emb.student_id not in latest_updated
                or emb.updated_at > latest_updated[emb.student_id]
            ):
                latest_updated[emb.student_id] = emb.updated_at

        result: list[FaceDataOut] = []
        for student_id, embs in grouped.items():
            result.append(
                FaceDataOut.from_orm(
                    student_id=student_id,
                    embeddings=embs,
                    updated_at=latest_updated[student_id],
                )
            )

        return result

    # ── Flutter legacy: import (file upload) ───────────────────
    async def import_from_file(self, file: UploadFile) -> dict:
        """PUT /api/employee/update/embedding

        Accepts a .json file upload containing:
        [ { "empId": 1, "listFaceEmbedding": [[...], ...], "updatedTime": "..." }, ... ]

        For each entry, atomically replaces that student's embeddings.
        Returns a summary: { "updated": N, "skipped": N, "errors": N }
        """
        if not file.filename or not file.filename.endswith(".json"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only .json files are accepted.",
            )

        raw = await file.read()
        try:
            payload: list[dict] = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid JSON: {exc}",
            )

        if not isinstance(payload, list):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="JSON root must be an array.",
            )

        updated = 0
        skipped = 0
        errors = 0

        for item in payload:
            emp_id = item.get("empId")
            vectors = item.get("listFaceEmbedding", [])

            if not isinstance(emp_id, int) or not vectors:
                errors += 1
                continue

            student = await self.student_repo.get_by_id(emp_id)
            if not student:
                skipped += 1
                continue

            try:
                await self.repo.replace_for_student(
                    student_id=emp_id,
                    embeddings=vectors,
                )
                updated += 1
            except Exception:
                errors += 1

        return {"updated": updated, "skipped": skipped, "errors": errors}
