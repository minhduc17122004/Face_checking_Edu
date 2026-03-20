from __future__ import annotations
"""Course service — CRUD for the /courses endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.course_repository import CourseRepository
from app.schemas.course_schema import CourseCreate, CourseOut, CourseList


class CourseService:
    """Business logic for course management."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = CourseRepository(db)

    async def create_course(
        self, req: CourseCreate, instructor_id: uuid.UUID
    ) -> CourseOut:
        course = await self.repo.create(
            course_name=req.course_name,
            instructor_id=instructor_id,
            subject=req.subject,
            course_code=req.course_code,
        )
        return CourseOut.model_validate(course)

    async def get_course(self, course_id: uuid.UUID) -> CourseOut:
        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        return CourseOut.model_validate(course)

    async def list_courses(self, skip: int = 0, limit: int = 200) -> CourseList:
        courses = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return CourseList(
            total=total,
            items=[CourseOut.model_validate(c) for c in courses],
        )

    async def list_my_courses(self, instructor_id: uuid.UUID) -> CourseList:
        """Return only courses owned by the requesting instructor."""
        courses = await self.repo.get_by_instructor(instructor_id)
        return CourseList(
            total=len(courses),
            items=[CourseOut.model_validate(c) for c in courses],
        )

    async def update_course(
        self,
        course_id: uuid.UUID,
        req: CourseCreate,
        instructor_id: uuid.UUID,
    ) -> CourseOut:
        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        if course.instructor_id != instructor_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this course.",
            )
        updated = await self.repo.update(
            course,
            course_name=req.course_name,
            subject=req.subject,
            course_code=req.course_code,
        )
        return CourseOut.model_validate(updated)

    async def delete_course(self, course_id: uuid.UUID, instructor_id: uuid.UUID) -> None:
        course = await self.repo.get_by_id(course_id)
        if not course:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Course '{course_id}' not found.",
            )
        if course.instructor_id != instructor_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not own this course.",
            )
        await self.repo.soft_delete(course)
