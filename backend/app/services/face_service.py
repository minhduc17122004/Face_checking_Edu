from __future__ import annotations
"""Face service — embedding registration, REST queries, and Flutter export/import."""
import hashlib
import json
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.repositories.face_repository import FaceRepository
from app.repositories.student_repository import StudentRepository
from app.repositories.device_repository import DeviceRepository
from app.models.face_embedding import FaceEmbedding
from app.schemas.face_schema import (
    FaceRegisterRequest,
    FaceEmbeddingOut,
    FaceEmbeddingList,
    FaceDataOut,
)
from app.schemas.v1.face import (
    FaceStatusResponse,
    FaceBulkExport,
    FaceExportItem,
)
from app.services.audit_service import AuditService


class FaceService:
    """Business logic for face embedding management.

    Supports:
    - v1: register with max-5 / FIFO eviction, face status, course export
    - REST: per-student register, retrieve
    - Flutter legacy: full export (GET) and file-based import (PUT)
    """

    MAX_EMBEDDINGS_PER_STUDENT = 5

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = FaceRepository(db)
        self.student_repo = StudentRepository(db)
        self.device_repo = DeviceRepository(db)
        self.audit = AuditService()

    # ── Embedding hash ─────────────────────────────────────────────────────────
    @staticmethod
    def _compute_embedding_hash(embeddings: list[list[float]]) -> str:
        """Deterministic SHA-256 hash of embedding vectors.

        Rounds floats to 6 decimal places to avoid precision drift between
        platforms (Python vs Dart vs DB storage), then produces a canonical
        JSON representation and hashes it.
        """
        if not embeddings:
            return ""
        rounded = [[round(x, 6) for x in vec] for vec in embeddings]
        canonical = json.dumps(rounded, separators=(',', ':'))
        return hashlib.sha256(canonical.encode('utf-8')).hexdigest()

    # ── v1: register with max-5 / FIFO ───────────────────────────────────────
    async def register_face_v1(
        self,
        student_id: int,
        embedding: list[float],
        device_id: uuid.UUID | None = None,
        quality_score: float | None = None,
    ) -> FaceEmbeddingOut:
        """Register a face embedding with max-5 / FIFO eviction.

        Business rules:
        1. Validate student exists.
        2. Validate device is active (optional).
        3. Count active embeddings.
        4. If >= 5: evict oldest (FIFO by created_at, hard delete).
        5. Insert new embedding with is_active=True.
        """
        student = await self.student_repo.get_by_id(student_id)
        if not student or student.deleted_at is not None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )

        if device_id:
            device = await self.device_repo.get_by_id(device_id)
            if not device or device.deleted_at is not None or not device.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Device is not valid or not active.",
                )

        count = await self.repo.get_active_count(student_id)
        evicted_id = None
        if count >= self.MAX_EMBEDDINGS_PER_STUDENT:
            # FIFO eviction: hard-delete the oldest active embedding
            result = await self.db.execute(
                select(FaceEmbedding)
                .where(
                    FaceEmbedding.student_id == student_id,
                    FaceEmbedding.is_active == True,  # noqa: E712
                )
                .order_by(FaceEmbedding.created_at.asc())
                .limit(1)
            )
            oldest = result.scalar_one_or_none()
            if oldest:
                evicted_id = oldest.id
                await self.db.delete(oldest)

        emb = FaceEmbedding(
            student_id=student_id,
            embedding=embedding,
            is_active=True,
            device_id=device_id,
            quality_score=quality_score,
        )
        self.db.add(emb)
        await self.db.flush()
        await self.db.refresh(emb)

        new_count = await self.repo.get_active_count(student_id)
        self.audit.log_face_registered(
            student_id=student_id,
            embedding_id=emb.id,
            embedding_count_after=new_count,
            device_id=device_id,
        )
        if evicted_id:
            self.audit.log_face_evicted(
                student_id=student_id,
                evicted_embedding_id=evicted_id,
                reason="fifo_max_reached",
            )

        return FaceEmbeddingOut.model_validate(emb)

    async def get_face_status(self, student_id: int) -> FaceStatusResponse:
        """GET /api/v1/students/{id}/face-status."""
        student = await self.student_repo.get_by_id(student_id)
        if not student or student.deleted_at is not None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Student {student_id} not found.",
            )
        count = await self.repo.get_active_count(student_id)
        return FaceStatusResponse(
            student_id=student_id,
            has_face=count > 0,
            total_embeddings=count,
        )

    async def export_for_course(self, course_id: uuid.UUID) -> FaceBulkExport:
        """GET /api/v1/courses/{id}/face-embeddings — all active embeddings for device."""
        embeddings = await self.repo.get_all_for_course(course_id)

        grouped: dict = defaultdict(list)
        for emb in embeddings:
            grouped[emb.student_id].append(emb)

        students: list[FaceExportItem] = []
        for sid, embs in grouped.items():
            all_vectors: list[list[float]] = []
            for e in embs:
                data = e.embedding
                if data and isinstance(data, list) and isinstance(data[0], list):
                    all_vectors.extend(data)
                elif data and isinstance(data, list):
                    all_vectors.append(data)
            latest = max(e.updated_at for e in embs)
            students.append(
                FaceExportItem(
                    student_id=sid,
                    embeddings=all_vectors,
                    updated_at=latest,
                )
            )

        return FaceBulkExport(
            course_id=course_id,
            students=students,
            exported_at=datetime.now(timezone.utc),
        )

    async def export_for_student_ids(
        self, student_ids: list[int]
    ) -> FaceBulkExport:
        """Export face embeddings for a specific list of student IDs."""
        embeddings = await self.repo.get_by_student_ids(student_ids)

        grouped: dict = defaultdict(list)
        for emb in embeddings:
            grouped[emb.student_id].append(emb)

        students: list[FaceExportItem] = []
        for sid, embs in grouped.items():
            all_vectors: list[list[float]] = []
            for e in embs:
                data = e.embedding
                if data and isinstance(data, list) and isinstance(data[0], list):
                    all_vectors.extend(data)
                elif data and isinstance(data, list):
                    all_vectors.append(data)
            latest = max(e.updated_at for e in embs)
            students.append(
                FaceExportItem(
                    student_id=sid,
                    embeddings=all_vectors,
                    updated_at=latest,
                )
            )

        return FaceBulkExport(
            course_id=None,
            students=students,
            exported_at=datetime.now(timezone.utc),
        )

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
    async def export_all(self, from_date: datetime | None = None, specific_student_ids: str | None = None) -> list[FaceDataOut]:
        """GET /api/student/export/json — all active embeddings for Flutter export.

        Returns deterministic output: sorted by student_id, deduplicated,
        with embedding_hash for client-side change detection.
        """
        from app.models.student import Student as StudentModel

        all_embeddings = await self.repo.get_all()
        if not all_embeddings:
            return []

        grouped: dict = defaultdict(list)
        latest_updated: dict = {}

        for emb in all_embeddings:
            grouped[emb.student_id].append(emb)
            if (
                emb.student_id not in latest_updated
                or emb.updated_at > latest_updated[emb.student_id]
            ):
                latest_updated[emb.student_id] = emb.updated_at

        parsed_ids = set()
        if specific_student_ids:
            try:
                parsed_ids = {int(x) for x in specific_student_ids.split(",") if x.strip()}
            except ValueError:
                pass

        # Filter by from_date / specific_student_ids
        if from_date:
            from datetime import timezone
            if from_date.tzinfo is None:
                from_date = from_date.replace(tzinfo=timezone.utc)
            filtered_grouped = {}
            for student_id, embs in grouped.items():
                if student_id in parsed_ids or latest_updated[student_id] > from_date:
                    filtered_grouped[student_id] = embs
            grouped = filtered_grouped
        elif parsed_ids:
            filtered_grouped = {}
            for student_id, embs in grouped.items():
                if student_id in parsed_ids:
                    filtered_grouped[student_id] = embs
            grouped = filtered_grouped

        if not grouped:
            return []

        # Batch-load student_code and name for all student IDs in one query
        from sqlalchemy.orm import selectinload
        student_ids = list(grouped.keys())
        students_result = await self.db.execute(
            select(StudentModel).options(selectinload(StudentModel.user)).where(
                StudentModel.id.in_(student_ids),
            )
        )
        student_map: dict[int, StudentModel] = {
            s.id: s for s in students_result.scalars().all()
        }

        result: list[FaceDataOut] = []
        # Sort by student_id for deterministic output
        for student_id in sorted(grouped.keys()):
            embs = grouped[student_id]
            student = student_map.get(student_id)

            # Flatten embeddings for hash computation
            all_vectors: list[list[float]] = []
            for e in embs:
                data = e.embedding
                if data and isinstance(data, list) and isinstance(data[0], list):
                    all_vectors.extend(data)
                elif data and isinstance(data, list):
                    all_vectors.append(data)

            emb_hash = self._compute_embedding_hash(all_vectors)

            result.append(
                FaceDataOut.build(
                    student_id=student_id,
                    embeddings=embs,
                    updated_at=latest_updated[student_id],
                    student_code=student.student_code if student else None,
                    person_name=student.name if student else None,
                    embedding_hash=emb_hash,
                )
            )

        return result

    # ── Flutter legacy: import (file upload) ───────────────────
    async def import_from_file(self, file: UploadFile) -> dict:
        """PUT /api/student/update/embedding — bulk face embedding import.

        Identity resolution order (stable across DB resets):
          1. ``studentCode``  — lookup by student_code (MSSV, unique)
          2. ``studentId``    — fallback to integer PK if studentCode missing/unknown

        This ensures sync works even if the backend DB was wiped and re-seeded
        with new auto-increment IDs, as long as student_code is consistent.
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
        skipped_ids = []
        errors = 0
        items_meta: list[dict] = []

        for item in payload:
            student_code: str | None = item.get("studentCode")  # MSSV — stable
            student_id_raw = item.get("studentId")              # DB PK — fallback
            vectors = item.get("listFaceEmbedding", [])

            if not vectors:
                errors += 1
                continue

            # ── Identity resolution ────────────────────────────────
            student = None

            # Step 1: Lookup by student_code (MSSV)
            if student_code and isinstance(student_code, str):
                student = await self.student_repo.get_by_code(student_code)

            # Step 2: Fallback to DB PK
            if student is None and isinstance(student_id_raw, int):
                student = await self.student_repo.get_by_id(student_id_raw)

            if student is None:
                # Cannot resolve identity — skip with the best available identifier
                skipped_ids.append(student_code or student_id_raw)
                continue

            try:
                new_embeddings = await self.repo.replace_for_student(
                    student_id=student.id,
                    embeddings=vectors,
                )
                updated += 1

                # ── Collect metadata for sync-echo elimination ─────
                # Compute the canonical hash the same way export_all does
                emb_hash = self._compute_embedding_hash(vectors)

                # Find the max updated_at across newly inserted rows
                max_updated_at = max(
                    (e.updated_at for e in new_embeddings),
                    default=datetime.now(timezone.utc),
                )

                items_meta.append({
                    "id": student.id,
                    "updated_at": max_updated_at.isoformat()
                                  if max_updated_at.tzinfo
                                  else max_updated_at.replace(tzinfo=timezone.utc).isoformat(),
                    "server_hash": emb_hash,
                })
            except Exception:
                errors += 1

        return {
            "message": "Cập nhật dữ liệu khuôn mặt thành công.",
            "data": {
                "updated": updated,
                "skipped": skipped_ids,
                "errors": errors,
                "items_meta": items_meta,
            }
        }
