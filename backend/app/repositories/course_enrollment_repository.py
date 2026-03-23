from __future__ import annotations
"""CourseEnrollment repository — async DB queries for the `course_enrollments` table."""
import uuid
from typing import Sequence

from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course_enrollment import CourseEnrollment
from app.repositories._base import BaseRepository


class CourseEnrollmentRepository(BaseRepository[CourseEnrollment]):
    """All database interactions for CourseEnrollment (student enrollment in courses)."""

    model = CourseEnrollment

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, enrollment_id: uuid.UUID) -> CourseEnrollment | None:
        result = await self.db.execute(
            select(CourseEnrollment).where(CourseEnrollment.id == enrollment_id)
        )
        return result.scalar_one_or_none()

    async def get_by_course(self, course_id: uuid.UUID) -> Sequence[CourseEnrollment]:
        result = await self.db.execute(
            select(CourseEnrollment).where(
                CourseEnrollment.course_id == course_id
            )
        )
        return result.scalars().all()

    async def get_by_student(self, student_id: int) -> Sequence[CourseEnrollment]:
        result = await self.db.execute(
            select(CourseEnrollment).where(
                CourseEnrollment.student_id == student_id
            )
        )
        return result.scalars().all()

    async def find_enrollment(
        self, course_id: uuid.UUID, student_id: int
    ) -> CourseEnrollment | None:
        result = await self.db.execute(
            select(CourseEnrollment).where(
                and_(
                    CourseEnrollment.course_id == course_id,
                    CourseEnrollment.student_id == student_id,
                )
            )
        )
        return result.scalar_one_or_none()

    async def count_by_course(self, course_id: uuid.UUID) -> int:
        result = await self.db.execute(
            select(func.count()).select_from(CourseEnrollment).where(
                CourseEnrollment.course_id == course_id
            )
        )
        return result.scalar_one()

    async def create(
        self,
        *,
        course_id: uuid.UUID,
        student_id: int,
    ) -> CourseEnrollment:
        """Enroll a student in a course."""
        enrollment = CourseEnrollment(
            course_id=course_id,
            student_id=student_id,
        )
        self.db.add(enrollment)
        await self.db.flush()
        await self.db.refresh(enrollment)
        return enrollment

    async def delete(self, enrollment: CourseEnrollment) -> None:
        """Remove a student from a course."""
        await self.db.delete(enrollment)
        await self.db.flush()

    # ── Student list with face status ─────────────────────────────────────────
    async def get_students_with_face_status(self, course_id: uuid.UUID):
        """Join course_enrollments + students + face_embeddings.

        Returns rows with:
        student_id, student_code, name, user_id, pin, enrolled_at, has_face, embedding_count
        """
        from app.models.student import Student
        from app.models.user import User
        from app.models.face_embedding import FaceEmbedding
        from sqlalchemy import select as sa_select, case

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
                CourseEnrollment.student_id,
                Student.student_code,
                User.full_name.label("name"),
                Student.user_id,  # For name lookup via user
                Student.pin,
                CourseEnrollment.enrolled_at,
                case((subq.c.emb_count.is_(None), False), else_=True).label("has_face"),
                func.coalesce(subq.c.emb_count, 0).label("embedding_count"),
            )
            .join(Student, CourseEnrollment.student_id == Student.id)
            .join(User, Student.user_id == User.id, isouter=True)
            .outerjoin(subq, CourseEnrollment.student_id == subq.c.sid)
            .where(
                and_(
                    CourseEnrollment.course_id == course_id,
                    Student.deleted_at.is_(None),
                )
            )
            .order_by(User.full_name)
        )
        return result.all()

    # ── Course list for a student ─────────────────────────────────────────────
    async def get_courses_for_student(self, student_id: int) -> Sequence[CourseEnrollment]:
        """Get all course enrollments for a student."""
        result = await self.db.execute(
            select(CourseEnrollment)
            .where(CourseEnrollment.student_id == student_id)
            .order_by(CourseEnrollment.enrolled_at.desc())
        )
        return result.scalars().all()

    # ── Students NOT enrolled in a course ─────────────────────────────────────
    async def get_available_students(
        self,
        course_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
    ):
        """Get students not enrolled in a specific course with face status and name."""
        from app.models.student import Student
        from app.models.user import User
        from app.models.face_embedding import FaceEmbedding
        from sqlalchemy import select as sa_select, case, not_

        subq = (
            select(
                FaceEmbedding.student_id.label("sid"),
                func.count(FaceEmbedding.id).label("emb_count"),
            )
            .where(FaceEmbedding.is_active == True)  # noqa: E712
            .group_by(FaceEmbedding.student_id)
            .subquery()
        )

        enrolled_subq = (
            select(CourseEnrollment.student_id)
            .where(CourseEnrollment.course_id == course_id)
            .subquery()
        )

        result = await self.db.execute(
            sa_select(
                Student.id,
                Student.user_id,
                Student.student_code,
                Student.pin,
                User.full_name,
                case((subq.c.emb_count.is_(None), False), else_=True).label("has_face"),
                func.coalesce(subq.c.emb_count, 0).label("embedding_count"),
            )
            .join(User, Student.user_id == User.id, isouter=True)
            .outerjoin(subq, Student.id == subq.c.sid)
            .where(
                and_(
                    Student.deleted_at.is_(None),
                    Student.id.notin_(select(enrolled_subq.c.student_id)),
                )
            )
            .offset(skip)
            .limit(limit)
            .order_by(User.full_name)
        )
        return result.all()

    async def count_available_students(self, course_id: uuid.UUID) -> int:
        """Count students not enrolled in a specific course."""
        from app.models.student import Student

        enrolled_subq = (
            select(CourseEnrollment.student_id)
            .where(CourseEnrollment.course_id == course_id)
            .subquery()
        )

        result = await self.db.execute(
            select(func.count(Student.id))
            .where(
                and_(
                    Student.deleted_at.is_(None),
                    Student.id.notin_(select(enrolled_subq.c.student_id)),
                )
            )
        )
        return result.scalar_one()
