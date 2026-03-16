"""Face embedding repository — raw async DB queries for `face_embeddings`."""
from typing import Sequence

from sqlalchemy import select, delete
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
            .where(FaceEmbedding.student_id == student_id)
            .order_by(FaceEmbedding.created_at)
        )
        return result.scalars().all()

    async def get_all(self) -> Sequence[FaceEmbedding]:
        """Return every embedding row — used by GET /api/employee/export/json."""
        result = await self.db.execute(
            select(FaceEmbedding).order_by(
                FaceEmbedding.student_id, FaceEmbedding.created_at
            )
        )
        return result.scalars().all()

    async def get_all_with_student_ids(self) -> Sequence[FaceEmbedding]:
        """Same as get_all() but explicit — alias for clarity at service layer."""
        return await self.get_all()

    async def get_students_with_embeddings(self) -> list[int]:
        """Return the distinct set of student IDs that have embeddings."""
        from sqlalchemy import distinct
        result = await self.db.execute(
            select(distinct(FaceEmbedding.student_id))
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
        """Atomic replace — delete existing rows then insert new vectors.

        Used by PUT /api/employee/update/embedding (Flutter push).
        Each element of `embeddings` is a single 128-d float list.
        Both old and new data live inside the same session transaction,
        so a failure rolls back automatically via get_db.
        """
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
