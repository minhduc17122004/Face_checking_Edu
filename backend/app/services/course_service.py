from __future__ import annotations
"""Course service — CRUD for the /courses endpoints."""
import uuid

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.course_repository import CourseRepository
from app.schemas.v1.course import CourseCreate, CourseUpdate, CourseOut, CourseList


class CourseService:
    """Business logic for course management."""

    def __init__(self, db: AsyncSession) -> None:
        self.repo = CourseRepository(db)
        self.db = db

    async def create_course(
        self, req: CourseCreate, instructor_id: uuid.UUID
    ) -> CourseOut:
        if req.department_id:
            from app.repositories.department_repository import DepartmentRepository
            dept_repo = DepartmentRepository(self.db)
            dept = await dept_repo.get_by_id(req.department_id)
            if not dept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Department not found.",
                )

        if req.room_id:
            from app.repositories.room_repository import RoomRepository
            room_repo = RoomRepository(self.db)
            room = await room_repo.get_by_id(req.room_id)
            if not room or room.is_deleted:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Room not found.",
                )

        course = await self.repo.create(
            course_name=req.course_name,
            instructor_id=instructor_id,
            subject=req.subject,
            course_code=req.course_code,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            attendance_before_minutes=req.attendance_before_minutes,
            attendance_after_minutes=req.attendance_after_minutes,
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

    async def list_courses(
        self, skip: int = 0, limit: int = 200, department_id: uuid.UUID | None = None
    ) -> CourseList:
        if department_id:
            courses = await self.repo.get_by_department(department_id)
            return CourseList(total=len(courses), items=[CourseOut.model_validate(c) for c in courses])
        courses = await self.repo.get_all(skip=skip, limit=limit)
        total = await self.repo.count()
        return CourseList(
            total=total,
            items=[CourseOut.model_validate(c) for c in courses],
        )

    async def list_my_courses(self, instructor_id: uuid.UUID) -> CourseList:
        courses = await self.repo.get_by_instructor(instructor_id)
        return CourseList(
            total=len(courses),
            items=[CourseOut.model_validate(c) for c in courses],
        )

    async def update_course(
        self,
        course_id: uuid.UUID,
        req: CourseUpdate,
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

        if req.department_id is not None:
            from app.repositories.department_repository import DepartmentRepository
            dept_repo = DepartmentRepository(self.db)
            dept = await dept_repo.get_by_id(req.department_id)
            if not dept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Department not found.",
                )

        if req.room_id is not None:
            from app.repositories.room_repository import RoomRepository
            room_repo = RoomRepository(self.db)
            room = await room_repo.get_by_id(req.room_id)
            if not room or room.is_deleted:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Room not found.",
                )

        updated = await self.repo.update(
            course,
            course_name=req.course_name,
            subject=req.subject,
            course_code=req.course_code,
            department_id=req.department_id,
            room_id=req.room_id,
            attendance_mode=req.attendance_mode,
            attendance_before_minutes=req.attendance_before_minutes,
            attendance_after_minutes=req.attendance_after_minutes,
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
