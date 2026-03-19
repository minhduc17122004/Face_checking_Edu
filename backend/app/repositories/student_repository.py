from __future__ import annotations
"""Student repository — raw async DB queries for the `students` table."""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.student import Student


class StudentRepository:
    """All database interactions for the Student model.

    Uses integer primary key (Flutter-compatible `id`).
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, student_id: int) -> Student | None:
        result = await self.db.execute(
            select(Student).where(
                Student.id == student_id,
                Student.is_deleted == False,  # noqa: E712
            )
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 500) -> Sequence[Student]:
        """Return all students ordered by ID ascending (Flutter sync order)."""
        result = await self.db.execute(
            select(Student)
            .where(Student.is_deleted == False)  # noqa: E712
            .offset(skip)
            .limit(limit)
            .order_by(Student.id)
        )
        return result.scalars().all()

    async def count(self) -> int:
        from sqlalchemy import func as sa_func
        result = await self.db.execute(select(sa_func.count()).select_from(Student))
        return result.scalar_one()

    async def get_by_name(self, name: str) -> Sequence[Student]:
        result = await self.db.execute(
            select(Student).where(Student.name.ilike(f"%{name}%"))
        )
        return result.scalars().all()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        name: str,
        pin: str | None = None,
        job_title: str | None = None,
        has_avatar: bool = False,
        attachment_id: str | None = None,
        avatar_url: str | None = None,
    ) -> Student:
        student = Student(
            name=name,
            pin=pin,
            job_title=job_title,
            has_avatar=has_avatar,
            attachment_id=attachment_id,
            avatar_url=avatar_url,
        )
        self.db.add(student)
        await self.db.flush()
        await self.db.refresh(student)
        return student

    async def update_avatar(
        self,
        student: Student,
        *,
        avatar_url: str,
        has_avatar: bool = True,
    ) -> Student:
        student.avatar_url = avatar_url
        student.has_avatar = has_avatar
        await self.db.flush()
        await self.db.refresh(student)
        return student

    async def mark_synced(self, student: Student) -> Student:
        student.is_synced = True
        await self.db.flush()
        return student

    async def delete(self, student: Student) -> None:
        await self.db.delete(student)
        await self.db.flush()

    async def bulk_create(
        self, students_data: list[dict]
    ) -> list[Student]:
        """Insert many students in one flush — used by the batch-create endpoint."""
        created: list[Student] = []
        for data in students_data:
            s = Student(**data)
            self.db.add(s)
            created.append(s)
        await self.db.flush()
        for s in created:
            await self.db.refresh(s)
        return created
