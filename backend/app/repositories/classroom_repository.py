from __future__ import annotations
"""Classroom repository — raw async DB queries for the `classes` table."""
import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.classroom import Classroom


class ClassroomRepository:
    """All database interactions for the Classroom model."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ── Read ──────────────────────────────────────────────────
    async def get_by_id(self, class_id: uuid.UUID) -> Classroom | None:
        result = await self.db.execute(
            select(Classroom).where(Classroom.id == class_id)
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 200) -> Sequence[Classroom]:
        result = await self.db.execute(
            select(Classroom)
            .offset(skip)
            .limit(limit)
            .order_by(Classroom.created_at.desc())
        )
        return result.scalars().all()

    async def get_by_teacher(self, teacher_id: uuid.UUID) -> Sequence[Classroom]:
        result = await self.db.execute(
            select(Classroom)
            .where(Classroom.teacher_id == teacher_id)
            .order_by(Classroom.created_at.desc())
        )
        return result.scalars().all()

    async def count(self) -> int:
        from sqlalchemy import func as sa_func
        result = await self.db.execute(select(sa_func.count()).select_from(Classroom))
        return result.scalar_one()

    # ── Write ─────────────────────────────────────────────────
    async def create(
        self,
        *,
        class_name: str,
        teacher_id: uuid.UUID | None = None,
        subject: str | None = None,
    ) -> Classroom:
        classroom = Classroom(
            class_name=class_name,
            teacher_id=teacher_id,
            subject=subject,
        )
        self.db.add(classroom)
        await self.db.flush()
        await self.db.refresh(classroom)
        return classroom

    async def update(
        self,
        classroom: Classroom,
        *,
        class_name: str | None = None,
        subject: str | None = None,
    ) -> Classroom:
        if class_name is not None:
            classroom.class_name = class_name
        if subject is not None:
            classroom.subject = subject
        await self.db.flush()
        await self.db.refresh(classroom)
        return classroom

    async def delete(self, classroom: Classroom) -> None:
        await self.db.delete(classroom)
        await self.db.flush()
