from __future__ import annotations
"""v1 Courses router — /api/v1/courses endpoints."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.course_service import CourseService
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.services._authorization import check_course_owner
from app.schemas.v1.course import (
    CourseCreate,
    CourseUpdate,
    CourseOut,
    CourseList,
    CourseStudentDetail,
    CourseStudentListResponse,
)
from app.schemas.v1.room import AssignRoomRequest

router = APIRouter(prefix="/courses", tags=["v1 — Courses"])


@router.post("/", response_model=CourseOut, status_code=status.HTTP_201_CREATED)
async def create_course(
    req: CourseCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new course."""
    svc = CourseService(db)
    course = await svc.create_course(req, uuid.UUID(user_id))
    await db.commit()
    return course


@router.get("/", response_model=CourseList)
async def list_courses(
    mine: bool = False,
    department_id: uuid.UUID | None = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all courses, optionally filtering by owner or department."""
    svc = CourseService(db)
    if mine:
        items = await svc.list_my_courses(uuid.UUID(user_id))
        return items
    return await svc.list_courses(skip=skip, limit=limit, department_id=department_id)


@router.get("/{course_id}", response_model=CourseOut)
async def get_course(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a single course."""
    svc = CourseService(db)
    return await svc.get_course(course_id)


@router.get("/{course_id}/students", response_model=CourseStudentListResponse)
async def list_course_students(
    course_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all students enrolled in a course, with face registration status."""
    enrollment_repo = CourseEnrollmentRepository(db)
    rows = await enrollment_repo.get_students_with_face_status(course_id)

    students = [
        CourseStudentDetail(
            student_id=row.student_id,
            user_id=str(row.user_id) if row.user_id else None,
            pin=row.pin,
            has_face=row.has_face,
            embedding_count=row.embedding_count,
            enrolled_at=row.enrolled_at,
        )
        for row in rows
    ]
    return CourseStudentListResponse(
        course_id=course_id,
        total=len(students),
        students=students,
    )


@router.post("/{course_id}/students/{student_id}", status_code=status.HTTP_201_CREATED)
async def enroll_student(
    course_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a course (owner only)."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    check_course_owner(course, user_id)

    enrollment_repo = CourseEnrollmentRepository(db)
    existing = await enrollment_repo.find_enrollment(course_id, student_id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student is already enrolled in this course.",
        )

    await enrollment_repo.create(course_id=course_id, student_id=student_id)
    await db.commit()
    return {"message": "Student enrolled."}


@router.put("/{course_id}", response_model=CourseOut)
async def update_course(
    course_id: uuid.UUID,
    req: CourseUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a course (owner only)."""
    svc = CourseService(db)
    return await svc.update_course(course_id, req, uuid.UUID(user_id))


@router.put("/{course_id}/assign-room", response_model=CourseOut)
async def assign_room_to_course(
    course_id: uuid.UUID,
    req: AssignRoomRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Assign a room to a course (owner only)."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    check_course_owner(course, user_id)

    # Validate room exists
    from app.repositories.room_repository import RoomRepository
    room_repo = RoomRepository(db)
    room = await room_repo.get_by_id(req.room_id)
    if not room or room.is_deleted:
        raise HTTPException(status_code=404, detail="Room not found.")

    # Update course room
    updated = await svc.repo.update(course, room_id=req.room_id)
    await db.commit()
    return CourseOut.model_validate(updated)


@router.delete("/{course_id}/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unenroll_student(
    course_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Remove a student from a course (owner only)."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    check_course_owner(course, user_id)

    enrollment_repo = CourseEnrollmentRepository(db)
    enrollment = await enrollment_repo.find_enrollment(course_id, student_id)
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    await enrollment_repo.delete(enrollment)
    await db.commit()


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_course(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Delete a course (owner only)."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    check_course_owner(course, user_id)
    await svc.delete_course(course_id, uuid.UUID(user_id))
    await db.commit()
