from __future__ import annotations
"""Course router — POST /courses, GET /courses, GET /courses/{course_id}."""
import uuid

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.course_schema import CourseCreate, CourseOut, CourseList
from app.services.course_service import CourseService

router = APIRouter(prefix="/courses", tags=["Courses"])


@router.post(
    "",
    response_model=CourseOut,
    status_code=201,
    summary="Create a new course",
)
async def create_course(
    body: CourseCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseOut:
    """Create a course owned by the authenticated teacher."""
    return await CourseService(db).create_course(body, instructor_id=uuid.UUID(user_id))


@router.get(
    "",
    response_model=CourseList,
    summary="List all courses",
)
async def list_courses(
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=1000),
    mine: bool = Query(False, description="If true, return only courses owned by the caller."),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseList:
    """Return a paginated list of courses. Use ?mine=true to filter to your own."""
    svc = CourseService(db)
    if mine:
        return await svc.list_my_courses(uuid.UUID(user_id))
    return await svc.list_courses(skip=skip, limit=limit)


@router.get(
    "/{course_id}",
    response_model=CourseOut,
    summary="Get a course by UUID",
)
async def get_course(
    course_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseOut:
    """Return the details of a specific course."""
    return await CourseService(db).get_course(course_id)


@router.put(
    "/{course_id}",
    response_model=CourseOut,
    summary="Update a course (owner only)",
)
async def update_course(
    course_id: uuid.UUID,
    body: CourseCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> CourseOut:
    """Update a course. Only the owning teacher may update it."""
    return await CourseService(db).update_course(course_id, body, instructor_id=uuid.UUID(user_id))


@router.delete(
    "/{course_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    summary="Delete a course (owner only)",
)
async def delete_course(
    course_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Delete a course. Only the owning teacher may delete it (403 otherwise)."""
    await CourseService(db).delete_course(course_id, instructor_id=uuid.UUID(user_id))
    return Response(status_code=status.HTTP_204_NO_CONTENT)
