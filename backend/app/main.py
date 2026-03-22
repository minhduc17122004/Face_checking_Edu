from __future__ import annotations
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.exc import (
    IntegrityError,
    OperationalError,
    DataError,
)

from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.rate_limit import limiter
from app.core.database import create_all_tables

# Import all models so SQLAlchemy metadata is fully populated before
# create_all_tables() runs. This is the canonical registration point.
import app.models  # noqa: F401, E402

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────
# Lifespan (startup / shutdown)
# ──────────────────────────────────────────────────────────────
_background_tasks: list = []


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _background_tasks
    # Startup
    try:
        import multipart  # type: ignore # noqa: F401
    except Exception as exc:
        logger.exception("Missing dependency python-multipart")
        raise RuntimeError(
            "python-multipart is required for multipart/form-data upload endpoints. "
            "Install it with: pip install python-multipart"
        ) from exc

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    await create_all_tables()

    # ── Phase 6: Auto-update session statuses on startup ──────────────────────
    try:
        from app.core.database import AsyncSessionLocal
        from app.services.session_auto_close import run_session_maintenance
        async with AsyncSessionLocal() as db:
            activated, closed = await run_session_maintenance(db)
            if activated or closed:
                logger.info(
                    "Session auto-update on startup: %d activated, %d closed",
                    activated, closed,
                )
    except Exception:
        logger.warning("Session auto-update on startup failed — non-critical", exc_info=True)

    # ── Phase 9: Start background session auto-close scheduler ───────────────
    import asyncio

    async def _session_scheduler() -> None:
        """Run session auto-close every hour."""
        while True:
            await asyncio.sleep(3600)  # 1 hour
            try:
                from app.core.database import AsyncSessionLocal
                from app.services.session_auto_close import run_session_maintenance
                async with AsyncSessionLocal() as db:
                    activated, closed = await run_session_maintenance(db)
                    if activated or closed:
                        logger.info(
                            "Background session maintenance: %d activated, %d closed",
                            activated, closed,
                        )
            except Exception:
                logger.warning("Background session maintenance failed", exc_info=True)

    _background_tasks.append(asyncio.create_task(_session_scheduler()))

    yield
    # Shutdown: cancel all background tasks
    for task in _background_tasks:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    _background_tasks.clear()


# ──────────────────────────────────────────────────────────────
# FastAPI application
# ──────────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.APP_NAME,
    description="Backend API for the Vedura AI Face Recognition Attendance System",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ──────────────────────────────────────────────────────────────
# Rate Limiting
# ──────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# ──────────────────────────────────────────────────────────────
# Global Exception Handlers
# ──────────────────────────────────────────────────────────────
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    logger.error("Request validation error on %s: %s", request.url.path, exc.errors())
    return JSONResponse(
        status_code=422,
        content={
            "message": "Request validation failed",
            "detail": exc.errors(),
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    logger.error("HTTP error on %s: %s", request.url.path, exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "message": exc.detail,
            "detail": exc.detail,
        },
        headers=exc.headers,
    )


@app.exception_handler(IntegrityError)
async def integrity_error_handler(request: Request, exc: IntegrityError) -> JSONResponse:
    logger.error("Integrity error on %s: %s", request.url.path, str(exc))
    error_str = str(exc).lower()
    if "unique" in error_str or "duplicate" in error_str:
        return JSONResponse(
            status_code=409,
            content={"message": "Duplicate entry", "detail": "A record with this value already exists."},
        )
    elif "foreign key" in error_str:
        return JSONResponse(
            status_code=422,
            content={"message": "Referenced record not found", "detail": "A foreign key constraint was violated."},
        )
    elif "check" in error_str:
        return JSONResponse(
            status_code=422,
            content={"message": "Constraint violation", "detail": "A data constraint was violated."},
        )
    return JSONResponse(
        status_code=409,
        content={"message": "Database integrity error", "detail": "A constraint was violated."},
    )


@app.exception_handler(OperationalError)
async def operational_error_handler(request: Request, exc: OperationalError) -> JSONResponse:
    logger.error("Operational error on %s: %s", request.url.path, str(exc))
    return JSONResponse(
        status_code=503,
        content={"message": "Database temporarily unavailable", "detail": "Please try again later."},
    )


@app.exception_handler(DataError)
async def data_error_handler(request: Request, exc: DataError) -> JSONResponse:
    logger.error("Data error on %s: %s", request.url.path, str(exc))
    return JSONResponse(
        status_code=422,
        content={"message": "Invalid data", "detail": "Data value is invalid or out of range."},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    import traceback
    from app.core.logger import app_logger
    app_logger.error(
        "Unhandled server error",
        exc_info=exc,
        extra={
            "path": request.url.path,
            "method": request.method,
            "error": str(exc),
        },
    )
    return JSONResponse(
        status_code=500,
        content={
            "message": "Internal server error",
            "detail": str(exc) if settings.DEBUG else "An unexpected error occurred.",
        },
    )


# ──────────────────────────────────────────────────────────────
# CORS
# ──────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ──────────────────────────────────────────────────────────────
# Static file serving (avatars / uploads)
# ──────────────────────────────────────────────────────────────
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


# ──────────────────────────────────────────────────────────────
# Routers — Phase 8 database refactor
# ──────────────────────────────────────────────────────────────
from fastapi import APIRouter

# Health check (Phase 8: enhanced with DB connectivity check)
from app.routers.v1.health import router as health_router

# ── v1 API (clean production-ready endpoints) ────────────────
# These replace the old /auth, /attendance, /attendance/new, etc.
from app.routers.v1 import api_v1_router

# ── Legacy routers (kept during Flutter migration) ────────────
# These will be removed once Flutter app is updated to v1 endpoints.
from app.routers.legacy_router import router as legacy_router

# Register all routers
app.include_router(health_router)               # /health, /health/ready, /health/live
app.include_router(api_v1_router)  # v1 endpoints at /api/v1/*
# Legacy routers (deprecated — will be removed after Flutter migration)
app.include_router(legacy_router)           # /api/* (Flutter legacy)
