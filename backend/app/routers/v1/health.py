from __future__ import annotations
"""Health check router — /api/v1/health and /health endpoints."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check() -> dict:
    """Basic health check — returns 200 if the service is up."""
    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/health/ready")
async def readiness_check(db: AsyncSession = Depends(get_db)) -> dict:
    """Readiness check — verifies DB connectivity."""
    try:
        await db.execute(text("SELECT 1"))
        return {
            "status": "ready",
            "database": "connected",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    except Exception as exc:
        return {
            "status": "not_ready",
            "database": "disconnected",
            "error": str(exc),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }


@router.get("/health/live")
async def liveness_check() -> dict:
    """Liveness check — returns 200 if the process is alive."""
    return {
        "status": "alive",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
