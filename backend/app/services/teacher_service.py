from __future__ import annotations
"""Teacher service — business logic for teacher management."""
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.teacher_repository import TeacherRepository
from app.schemas.v1.teacher import TeacherOut, TeacherList


class TeacherService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = TeacherRepository(db)

    async def _to_out(self, teacher) -> TeacherOut:
        department_name = None
        user_full_name = None
        if teacher.department_rel:
            department_name = teacher.department_rel.name
        if teacher.user:
            user_full_name = teacher.user.full_name
        return TeacherOut(
            id=teacher.id,
            user_id=teacher.user_id,
            teacher_id=teacher.teacher_id,
            phone=teacher.phone,
            department_id=teacher.department_id,
            department_name=department_name,
            user_full_name=user_full_name,
            created_at=teacher.created_at,
            updated_at=teacher.updated_at,
        )

    async def get_teacher(self, teacher_id: int) -> TeacherOut:
        teacher = await self.repo.get_by_id(teacher_id)
        if not teacher:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Teacher not found.")
        return await self._to_out(teacher)

    async def list_teachers(
        self,
        department_id: uuid.UUID | None = None,
        skip: int = 0,
        limit: int = 100,
    ) -> TeacherList:
        if department_id:
            items, total = await self.repo.get_by_department(department_id, skip=skip, limit=limit)
        else:
            items, total = await self.repo.list(skip=skip, limit=limit)
        return TeacherList(total=total, items=[await self._to_out(t) for t in items])

    async def assign_department(self, teacher_id: int, department_id: uuid.UUID) -> TeacherOut:
        from app.repositories.department_repository import DepartmentRepository
        teacher = await self.repo.get_by_id(teacher_id)
        if not teacher:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Teacher not found.")
        dept_repo = DepartmentRepository(self.db)
        dept = await dept_repo.get_by_id(department_id)
        if not dept:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Department not found.")
        updated = await self.repo.assign_department(teacher, department_id)
        updated.department_rel = dept
        return await self._to_out(updated)

    async def remove_department(self, teacher_id: int) -> TeacherOut:
        teacher = await self.repo.get_by_id(teacher_id)
        if not teacher:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Teacher not found.")
        updated = await self.repo.remove_department(teacher)
        return await self._to_out(updated)
