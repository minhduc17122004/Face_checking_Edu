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
@asynccontextmanager
async def lifespan(app: FastAPI):
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
        from app.repositories.session_repository import SessionRepository
        async with AsyncSessionLocal() as db:
            repo = SessionRepository(db)
            activated, closed = await repo.auto_update_status()
            if activated or closed:
                await db.commit()
                logger.info(
                    "Session auto-update on startup: %d activated, %d closed",
                    activated, closed,
                )
    except Exception:
        logger.warning("Session auto-update on startup failed — non-critical", exc_info=True)

    yield
    # Shutdown (nothing to clean up for now)


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
    logger.exception("Unhandled server error on %s", request.url.path)
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

# Health check
health_router = APIRouter(tags=["Health"])


@health_router.get("/health", summary="Service health check")
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": "1.0.0"}


# ── v1 API (clean production-ready endpoints) ────────────────
# These replace the old /auth, /attendance, /attendance/new, etc.
from app.routers.v1 import api_v1_router

# ── Legacy routers (kept during Flutter migration) ────────────
# These will be removed once Flutter app is updated to v1 endpoints.
from app.routers.auth_router import router as auth_router
from app.routers.user_router import router as user_router
from app.routers.student_router import router as student_router
from app.routers.course_router import router as course_router
from app.routers.attendance_router import router as attendance_router
from app.routers.face_router import router as face_router
from app.routers.device_router import router as device_router
from app.routers.legacy_router import router as legacy_router
from app.routers.time_slot_router import router as time_slot_router
from app.routers.course_enrollment_router import router as course_enrollment_router
from app.routers.schedule_router import router as schedule_router
from app.routers.session_router import router as session_router
from app.routers.attendance_new_router import router as attendance_new_router
from app.routers.student_group_router import router as student_group_router

# Register all routers
app.include_router(health_router)
app.include_router(api_v1_router)  # v1 endpoints at /api/v1/*
# Legacy routers (deprecated — will be removed after Flutter migration)
app.include_router(auth_router)             # /auth/*
app.include_router(user_router)             # /users/*
app.include_router(student_router)          # /students/*
app.include_router(course_router)            # /courses/*
app.include_router(attendance_router)        # /attendance/*
app.include_router(face_router)             # /face/*
app.include_router(device_router)           # /devices/*
app.include_router(legacy_router)           # /api/* (Flutter legacy)
app.include_router(time_slot_router)        # /time-slots/*
app.include_router(course_enrollment_router)  # /course-enrollments/*
app.include_router(schedule_router)         # /schedules/*
app.include_router(session_router)          # /sessions/*
app.include_router(attendance_new_router)   # /attendance/new/*
app.include_router(student_group_router)     # /student-groups/*
