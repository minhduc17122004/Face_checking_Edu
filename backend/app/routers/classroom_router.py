from __future__ import annotations
"""Classroom router — POST /classes, GET /classes, GET /classes/{class_id}."""
import uuid

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.classroom_schema import ClassCreate, ClassOut, ClassList
from app.services.classroom_service import ClassroomService

router = APIRouter(prefix="/classes", tags=["Classes"])


@router.post(
    "",
    response_model=ClassOut,
    status_code=201,
    summary="Create a new classroom",
)
async def create_class(
    body: ClassCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ClassOut:
    """Create a classroom owned by the authenticated teacher."""
    return await ClassroomService(db).create_class(body, teacher_id=uuid.UUID(user_id))


@router.get(
    "",
    response_model=ClassList,
    summary="List all classes",
)
async def list_classes(
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=1000),
    mine: bool = Query(False, description="If true, return only classes owned by the caller."),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ClassList:
    """Return a paginated list of classes. Use ?mine=true to filter to your own."""
    svc = ClassroomService(db)
    if mine:
        return await svc.list_my_classes(uuid.UUID(user_id))
    return await svc.list_classes(skip=skip, limit=limit)


@router.get(
    "/{class_id}",
    response_model=ClassOut,
    summary="Get a classroom by UUID",
)
async def get_class(
    class_id: uuid.UUID,
    _: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ClassOut:
    """Return the details of a specific classroom."""
    return await ClassroomService(db).get_class(class_id)


@router.delete(
    "/{class_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
    summary="Delete a classroom (owner only)",
)
async def delete_class(
    class_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Delete a classroom. Only the owning teacher may delete it (403 otherwise)."""
    await ClassroomService(db).delete_class(class_id, teacher_id=uuid.UUID(user_id))
    return Response(status_code=status.HTTP_204_NO_CONTENT)
