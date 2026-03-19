from __future__ import annotations
"""Face repository — raw async DB queries for `face_embeddings`."""
import uuid
from typing import Sequence

from sqlalchemy import select, delete, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.face_embedding import FaceEmbedding


class FaceRepository:
    """All database interactions for FaceEmbedding.

    Designed to support:
    - Per-student upsert (Flutter push) — replaces all existing embeddings.
    - Full export (Flutter pull) — returns all students' embeddings.
    - Per-student read (REST query).
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_student(self, student_id: int) -> Sequence[FaceEmbedding]:
        """Return all embedding records for a single student."""
        result = await self.db.execute(
            select(FaceEmbedding)
            .where(
                and_(
                    FaceEmbedding.student_id == student_id,
                    FaceEmbedding.is_active == True,  # noqa: E712
                )
            )
            .order_by(FaceEmbedding.created_at)
        )
        return result.scalars().all()

    async def get_all(self) -> Sequence[FaceEmbedding]:
        """Return every embedding row — used by GET /api/employee/export/json."""
        result = await self.db.execute(
            select(FaceEmbedding)
            .where(FaceEmbedding.is_active == True)  # noqa: E712
            .order_by(FaceEmbedding.student_id, FaceEmbedding.created_at)
        )
        return result.scalars().all()

    async def get_active_count(self, student_id: int) -> int:
        """Return count of active embeddings for a student."""
        from sqlalchemy import func
        result = await self.db.execute(
            select(func.count())
            .select_from(FaceEmbedding)
            .where(
                and_(
                    FaceEmbedding.student_id == student_id,
                    FaceEmbedding.is_active == True,  # noqa: E712
                )
            )
        )
        return result.scalar_one()

    async def get_oldest_inactive(self, student_id: int) -> FaceEmbedding | None:
        """Return the oldest embedding for a student (FIFO eviction candidate)."""
        result = await self.db.execute(
            select(FaceEmbedding)
            .where(
                and_(
                    FaceEmbedding.student_id == student_id,
                    FaceEmbedding.is_active == False,  # noqa: E712
                )
            )
            .order_by(FaceEmbedding.created_at.asc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_students_with_embeddings(self) -> list[int]:
        """Return the distinct set of student IDs that have embeddings."""
        from sqlalchemy import distinct
        result = await self.db.execute(
            select(distinct(FaceEmbedding.student_id))
            .where(FaceEmbedding.is_active == True)  # noqa: E712
        )
        return list(result.scalars().all())

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        student_id: int,
        embedding_data: list,
    ) -> FaceEmbedding:
        """Insert a single embedding row."""
        emb = FaceEmbedding(student_id=student_id, embedding_data=embedding_data)
        self.db.add(emb)
        await self.db.flush()
        await self.db.refresh(emb)
        return emb

    async def replace_for_student(
        self,
        student_id: int,
        embeddings: list[list[float]],
    ) -> list[FaceEmbedding]:
        """Atomic replace — delete existing rows then insert new vectors."""
        # 1. Delete existing embeddings for this student
        await self.db.execute(
            delete(FaceEmbedding).where(FaceEmbedding.student_id == student_id)
        )
        await self.db.flush()

        # 2. Insert fresh embeddings
        created: list[FaceEmbedding] = []
        for vector in embeddings:
            emb = FaceEmbedding(student_id=student_id, embedding_data=vector)
            self.db.add(emb)
            created.append(emb)

        await self.db.flush()
        for emb in created:
            await self.db.refresh(emb)
        return created

    async def delete_for_student(self, student_id: int) -> int:
        """Delete all embeddings for a student. Returns number of rows deleted."""
        result = await self.db.execute(
            delete(FaceEmbedding).where(FaceEmbedding.student_id == student_id)
        )
        await self.db.flush()
        return result.rowcount

    async def delete_one(self, emb: FaceEmbedding) -> None:
        await self.db.delete(emb)
        await self.db.flush()

    # ── Classroom face export (Phase 4) ──────────────────────────────────────
    async def get_all_for_classroom(self, classroom_id: uuid.UUID) -> Sequence[FaceEmbedding]:
        """Return all active embeddings for students enrolled in a classroom.

        Used by GET /api/v1/classrooms/{id}/face-embeddings for device sync.
        """
        from app.models.classroom_student import ClassroomStudent
        from sqlalchemy import select as sa_select

        result = await self.db.execute(
            sa_select(FaceEmbedding)
            .join(ClassroomStudent, FaceEmbedding.student_id == ClassroomStudent.student_id)
            .where(
                and_(
                    ClassroomStudent.classroom_id == classroom_id,
                    FaceEmbedding.is_active == True,  # noqa: E712
                )
            )
            .order_by(FaceEmbedding.student_id, FaceEmbedding.created_at)
        )
        return result.scalars().all()
