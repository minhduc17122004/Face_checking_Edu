from __future__ import annotations
"""v1 Courses router — thin layer, no business logic."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.course_service import CourseService
from app.repositories.course_enrollment_repository import CourseEnrollmentRepository
from app.schemas.v1.course import (
    CourseCreate,
    CourseUpdate,
    CourseOut,
    CourseList,
    CourseStudentDetail,
    CourseStudentListResponse,
    BatchEnrollRequest,
    BatchEnrollResponse,
    BatchEnrollResult,
    AvailableStudentDetail,
    AvailableStudentListResponse,
)
from app.schemas.v1.room import AssignRoomRequest

router = APIRouter(prefix="/courses", tags=["v1 — Courses"])


# ── Thin helpers ────────────────────────────────────────────────────────────

def _get_current_teacher_id(req_teacher_id: int | None, user_id: str) -> tuple[int | None, str]:
    """Return (teacher_id, user_id) tuple for service resolution.

    Router passes this directly to service; all resolution happens in service layer.
    """
    return req_teacher_id, user_id


# ── Endpoints ───────────────────────────────────────────────────────────────


@router.post("/", response_model=CourseOut, status_code=status.HTTP_201_CREATED)
async def create_course(
    req: CourseCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new course. Passes teacher_id (if admin) and user_id to service."""
    svc = CourseService(db)
    course = await svc.create_course(req, teacher_id=req.teacher_id, user_id=user_id)
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
        return await svc.list_my_courses(teacher_id=None, user_id=user_id)
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
            student_code=row.student_code,
            name=row.name,
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


@router.get("/{course_id}/available-students", response_model=AvailableStudentListResponse)
async def list_available_students(
    course_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List students not enrolled in a course, with face status."""
    enrollment_repo = CourseEnrollmentRepository(db)
    rows = await enrollment_repo.get_available_students(course_id, skip=skip, limit=limit)
    total = await enrollment_repo.count_available_students(course_id)

    students = [
        AvailableStudentDetail(
            id=row.id,
            user_id=str(row.user_id) if row.user_id else None,
            student_code=row.student_code,
            pin=row.pin,
            full_name=row.full_name,
            has_face=row.has_face,
            embedding_count=row.embedding_count,
        )
        for row in rows
    ]
    return AvailableStudentListResponse(
        course_id=course_id,
        total=total,
        students=students,
    )


@router.post("/{course_id}/students/batch", response_model=BatchEnrollResponse)
async def batch_enroll_students(
    course_id: uuid.UUID,
    req: BatchEnrollRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll multiple students in a course (owner only)."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    resolved_teacher_id = await svc._resolve_teacher_id(teacher_id=None, user_id=user_id, required=False)

    # Admin (resolved_teacher_id is None) can enroll in any course
    # Teacher can only enroll in their own courses
    if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not own this course.",
        )

    enrollment_repo = CourseEnrollmentRepository(db)

    results = []
    total_enrolled = 0
    total_already = 0

    for student_id in req.student_ids:
        existing = await enrollment_repo.find_enrollment(course_id, student_id)
        if existing:
            results.append(BatchEnrollResult(
                student_id=student_id,
                success=False,
                message="Student is already enrolled.",
            ))
            total_already += 1
        else:
            await enrollment_repo.create(course_id=course_id, student_id=student_id)
            results.append(BatchEnrollResult(
                student_id=student_id,
                success=True,
                message="Enrolled successfully.",
            ))
            total_enrolled += 1

    await db.commit()
    return BatchEnrollResponse(
        course_id=course_id,
        total_requested=len(req.student_ids),
        total_enrolled=total_enrolled,
        total_already_enrolled=total_already,
        results=results,
    )


@router.post("/{course_id}/students/{student_id}", status_code=status.HTTP_201_CREATED)
async def enroll_student(
    course_id: uuid.UUID,
    student_id: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Enroll a student in a course (owner only). Service resolves ownership."""
    svc = CourseService(db)
    course = await svc.get_course(course_id)
    # Service validates ownership internally
    resolved_teacher_id = await svc._resolve_teacher_id(teacher_id=None, user_id=user_id, required=False)

    # Admin (resolved_teacher_id is None) can enroll in any course
    # Teacher can only enroll in their own courses
    if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not own this course.",
        )

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
    """Update a course (owner only). Passes teacher_id (if reassigning) and user_id to service."""
    svc = CourseService(db)
    course = await svc.update_course(
        course_id,
        req,
        teacher_id=req.teacher_id,
        user_id=user_id,
    )
    await db.commit()
    return course


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
    resolved_teacher_id = await svc._resolve_teacher_id(teacher_id=None, user_id=user_id, required=False)

    # Admin (resolved_teacher_id is None) can assign room to any course
    # Teacher can only assign room to their own courses
    if resolved_teacher_id is not None and course.teacher_id != resolved_teacher_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not own this course.",
        )

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
    # Service validates ownership
    await svc._resolve_teacher_id(teacher_id=None, user_id=user_id)

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
    await svc.delete_course(course_id, teacher_id=None, user_id=user_id)
    await db.commit()
