from __future__ import annotations
"""Department service — business logic for department management."""
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.department_repository import DepartmentRepository
from app.schemas.v1.department import (
    DepartmentCreate,
    DepartmentOut,
    DepartmentWithStats,
    DepartmentList,
)


class DepartmentService:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = DepartmentRepository(db)

    async def create_department(self, req: DepartmentCreate) -> DepartmentOut:
        existing = await self.repo.get_by_code(req.code)
        if existing:
            from fastapi import HTTPException
            raise HTTPException(
                status_code=409,
                detail=f"Department with code '{req.code}' already exists.",
            )
        dept = await self.repo.create(
            code=req.code,
            name=req.name,
        )
        return DepartmentOut.model_validate(dept)

    async def get_department(self, department_id: uuid.UUID) -> DepartmentOut:
        dept = await self.repo.get_by_id(department_id)
        if not dept:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Department not found.")
        return DepartmentOut.model_validate(dept)

    async def list_departments(
        self,
        skip: int = 0,
        limit: int = 100,
    ) -> DepartmentList:
        items, total = await self.repo.list(skip=skip, limit=limit)
        return DepartmentList(
            total=total,
            items=[DepartmentOut.model_validate(d) for d in items],
        )

    async def update_department(
        self,
        department_id: uuid.UUID,
        req: DepartmentCreate,
    ) -> DepartmentOut:
        dept = await self.repo.get_by_id(department_id)
        if not dept:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Department not found.")

        if req.code != dept.code:
            existing = await self.repo.get_by_code(req.code)
            if existing:
                from fastapi import HTTPException
                raise HTTPException(
                    status_code=409,
                    detail=f"Department with code '{req.code}' already exists.",
                )

        updated = await self.repo.update(
            dept,
            code=req.code,
            name=req.name,
        )
        return DepartmentOut.model_validate(updated)

    async def delete_department(self, department_id: uuid.UUID) -> None:
        dept = await self.repo.get_by_id(department_id)
        if not dept:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Department not found.")

        # Guard: prevent deletion if teachers are assigned
        teacher_count = await self.repo.count_teachers(department_id)
        if teacher_count > 0:
            from fastapi import HTTPException
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete department with {teacher_count} teacher(s) assigned.",
            )

        # Guard: prevent deletion if courses are assigned
        course_count = await self.repo.count_courses(department_id)
        if course_count > 0:
            from fastapi import HTTPException
            raise HTTPException(
                status_code=400,
                detail=f"Cannot delete department with {course_count} course(s) assigned.",
            )

        await self.repo.soft_delete(dept)

    async def get_department_with_stats(
        self,
        department_id: uuid.UUID,
    ) -> DepartmentWithStats:
        dept = await self.repo.get_by_id(department_id)
        if not dept:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Department not found.")
        teacher_count = await self.repo.count_teachers(department_id)
        student_count = await self.repo.count_student_groups(department_id)
        out = DepartmentOut.model_validate(dept)
        return DepartmentWithStats(
            **out.model_dump(),
            teacher_count=teacher_count,
            student_count=student_count,
        )
