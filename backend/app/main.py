import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.core.database import create_all_tables

# Import all models so SQLAlchemy metadata is fully populated before
# create_all_tables() runs. This is the canonical registration point.
import app.models  # noqa: F401, E402


# ──────────────────────────────────────────────────────────────
# Lifespan (startup / shutdown)
# ──────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
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
app.include_router(legacy_router)
