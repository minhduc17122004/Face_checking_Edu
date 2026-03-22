from __future__ import annotations
"""v1 Departments router — /api/v1/departments endpoints."""
import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_id
from app.core.database import get_db
from app.services.department_service import DepartmentService
from app.schemas.v1.department import (
    DepartmentCreate,
    DepartmentUpdate,
    DepartmentOut,
    DepartmentList,
)

router = APIRouter(prefix="/departments", tags=["v1 — Departments"])


@router.post("", response_model=DepartmentOut, status_code=201)
async def create_department(
    req: DepartmentCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Create a new department."""
    svc = DepartmentService(db)
    return await svc.create_department(req)


@router.get("", response_model=DepartmentList)
async def list_departments(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """List all departments with pagination."""
    svc = DepartmentService(db)
    return await svc.list_departments(skip=skip, limit=limit)


@router.get("/{department_id}", response_model=DepartmentOut)
async def get_department(
    department_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Get a department by ID."""
    svc = DepartmentService(db)
    return await svc.get_department(department_id)


@router.put("/{department_id}", response_model=DepartmentOut)
async def update_department(
    department_id: uuid.UUID,
    req: DepartmentUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Update a department."""
    svc = DepartmentService(db)
    return await svc.update_department(department_id, req)


@router.delete("/{department_id}", status_code=204)
async def delete_department(
    department_id: uuid.UUID,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a department."""
    svc = DepartmentService(db)
    await svc.delete_department(department_id)
    await db.commit()
