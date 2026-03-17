from __future__ import annotations
"""Student router — modern REST CRUD for /students."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.student_schema import StudentCreate, StudentOut, StudentList
from app.services.student_service import StudentService

router = APIRouter(prefix="/students", tags=["Students"])


@router.post(
    "",
    response_model=StudentOut,
    status_code=201,
    summary="Create a new student",
)
async def create_student(
    body: StudentCreate,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentOut:
    """Create a single student record (modern REST endpoint)."""
    return await StudentService(db).create_student(body)


@router.get(
    "",
    response_model=StudentList,
    summary="List all students",
)
async def list_students(
    skip: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=5000),
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentList:
    """Return a paginated list of all students."""
    return await StudentService(db).list_students(skip=skip, limit=limit)


@router.get(
    "/{student_id}",
    response_model=StudentOut,
    summary="Get a student by integer ID",
)
async def get_student(
    student_id: int,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StudentOut:
    """Return the full profile for a specific student."""
    return await StudentService(db).get_student(student_id)
