from __future__ import annotations
"""Classroom service — CRUD for the /classes endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.classroom_repository import ClassroomRepository
from app.schemas.classroom_schema import ClassCreate, ClassOut, ClassList


class ClassroomService:
    """Business logic for classroom management."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = ClassroomRepository(db)

    async def create_class(
        self, req: ClassCreate, teacher_id: uuid.UUID
    ) -> ClassOut:
        classroom = await self.repo.create(
            class_name=req.class_name,
            teacher_id=teacher_id,
            subject=req.subject,
        )
        return ClassOut.model_validate(classroom)

    async def get_class(self, class_id: uuid.UUID) -> ClassOut:
        classroom = await self.repo.get_by_id(class_id)
        if not classroom:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Class '{class_id}' not found.",
            )
        return ClassOut.model_validate(classroom)

    async def list_classes(self, skip: int = 0, limit: int = 200) -> ClassList:
        classes = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return ClassList(
            total=total,
            items=[ClassOut.model_validate(c) for c in classes],
        )

    async def list_my_classes(self, teacher_id: uuid.UUID) -> ClassList:
        """Return only classes owned by the requesting teacher."""
        classes = await self.repo.get_by_teacher(teacher_id)
        return ClassList(
            total=len(classes),
            items=[ClassOut.model_validate(c) for c in classes],
        )

    async def delete_class(self, class_id: uuid.UUID, teacher_id: uuid.UUID) -> None:
        classroom = await self.repo.get_by_id(class_id)
        if not classroom:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Class '{class_id}' not found.",
            )
        if classroom.teacher_id != teacher_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this class.",
            )
        await self.repo.delete(classroom)
