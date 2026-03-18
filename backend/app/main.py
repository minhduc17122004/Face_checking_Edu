from __future__ import annotations
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

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
    # Ensure multipart parser dependency exists for UploadFile/FormData routes.
    try:
        import multipart  # type: ignore # noqa: F401
    except Exception as exc:
        logger.exception("Missing dependency python-multipart")
        raise RuntimeError(
            "python-multipart is required for multipart/form-data upload endpoints. "
            "Install it with: pip install python-multipart"
        ) from exc

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    # Create tables if they don't exist (Alembic handles migrations in prod)
    await create_all_tables()
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
            "message": "Request failed",
            "detail": exc.detail,
        },
        headers=exc.headers,
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled server error on %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={
            "message": "Internal server error",
            "detail": str(exc),
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
# Routers  ✅ Phase 6 — all domain routers registered
# ──────────────────────────────────────────────────────────────
from fastapi import APIRouter

# Domain routers
from app.routers.auth_router import router as auth_router
from app.routers.user_router import router as user_router
from app.routers.student_router import router as student_router
from app.routers.classroom_router import router as classroom_router
from app.routers.attendance_router import router as attendance_router
from app.routers.face_router import router as face_router
from app.routers.device_router import router as device_router

# Flutter legacy API router (Phase 7)
from app.routers.legacy_router import router as legacy_router

# Health check
health_router = APIRouter(tags=["Health"])


@health_router.get("/health", summary="Service health check")
async def health_check():
    return {"status": "ok", "app": settings.APP_NAME, "version": "1.0.0"}


# Register all routers
app.include_router(health_router)
app.include_router(auth_router)
app.include_router(user_router)
app.include_router(student_router)
app.include_router(classroom_router)
app.include_router(attendance_router)
app.include_router(face_router)
app.include_router(device_router)
app.include_router(legacy_router)
