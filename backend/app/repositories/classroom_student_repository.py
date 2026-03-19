from __future__ import annotations
"""ClassroomStudent repository — async DB queries for the `classroom_students` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.classroom_student import ClassroomStudent
from app.repositories._base import BaseRepository


class ClassroomStudentRepository(BaseRepository[ClassroomStudent]):
    """All database interactions for ClassroomStudent (enrollment)."""

    model = ClassroomStudent

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, enrollment_id: uuid.UUID) -> ClassroomStudent | None:
        result = await self.db.execute(
            select(ClassroomStudent).where(ClassroomStudent.id == enrollment_id)
        )
        return result.scalar_one_or_none()

    async def get_by_classroom(self, classroom_id: uuid.UUID) -> Sequence[ClassroomStudent]:
        result = await self.db.execute(
            select(ClassroomStudent).where(
                ClassroomStudent.classroom_id == classroom_id
            )
        )
        return result.scalars().all()

    async def get_by_student(self, student_id: int) -> Sequence[ClassroomStudent]:
        result = await self.db.execute(
            select(ClassroomStudent).where(
                ClassroomStudent.student_id == student_id
            )
        )
        return result.scalars().all()

    async def find_enrollment(
        self, classroom_id: uuid.UUID, student_id: int
    ) -> ClassroomStudent | None:
        result = await self.db.execute(
            select(ClassroomStudent).where(
                and_(
                    ClassroomStudent.classroom_id == classroom_id,
                    ClassroomStudent.student_id == student_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def count_by_classroom(self, classroom_id: uuid.UUID) -> int:
        from sqlalchemy import func
        result = await self.db.execute(
            select(func.count()).select_from(ClassroomStudent).where(
                ClassroomStudent.classroom_id == classroom_id
            )
        )
        return result.scalar_one()

    async def create(
        self,
        *,
        classroom_id: uuid.UUID,
        student_id: int,
    ) -> ClassroomStudent:
        """Enroll a student in a classroom."""
        enrollment = ClassroomStudent(
            classroom_id=classroom_id,
            student_id=student_id,
        )
        self.db.add(enrollment)
        await self.db.flush()
        await self.db.refresh(enrollment)
        return enrollment

    # ── Phase 3: Student list with face status ──────────────────────────────
    async def get_students_with_face_status(self, classroom_id: uuid.UUID):
        """Join classroom_students + students + face_embeddings.

        Returns rows with:
        student_id, name, pin, enrolled_at, has_face, embedding_count
        """
        from app.models.student import Student
        from app.models.face_embedding import FaceEmbedding
        from sqlalchemy import func, select as sa_select, case

        subq = (
            select(
                FaceEmbedding.student_id.label("sid"),
                func.count(FaceEmbedding.id).label("emb_count"),
            )
            .where(FaceEmbedding.is_active == True)  # noqa: E712
            .group_by(FaceEmbedding.student_id)
            .subquery()
        )

        result = await self.db.execute(
            sa_select(
                ClassroomStudent.student_id,
                Student.name,
                Student.pin,
                ClassroomStudent.enrolled_at,
                case((subq.c.emb_count.is_(None), False), else_=True).label("has_face"),
                func.coalesce(subq.c.emb_count, 0).label("embedding_count"),
            )
            .join(Student, ClassroomStudent.student_id == Student.id)
            .outerjoin(subq, ClassroomStudent.student_id == subq.c.sid)
            .where(
                and_(
                    ClassroomStudent.classroom_id == classroom_id,
                    Student.is_deleted == False,  # noqa: E712
                )
            )
            .order_by(Student.name)
        )
        return result.all()
