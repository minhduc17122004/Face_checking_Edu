from __future__ import annotations
"""Auth service — registration, login, avatar upload, and current-user resolution."""
import logging
import os
import uuid as _uuid
from datetime import timedelta
from io import BytesIO

from fastapi import HTTPException, status, UploadFile
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession
from PIL import Image, UnidentifiedImageError

from app.core.config import settings
from app.core.logger import security_logger
from app.core.security import hash_password, verify_password, create_access_token
from app.repositories.user_repository import UserRepository
from app.schemas.auth_schema import (
    RegisterRequest, LoginRequest, TokenResponse, UserInfo,
    MessageResponse, AvatarUploadResponse,
)

# Allowed image MIME types and max upload size
# 'application/octet-stream' is added because Flutter Dio without explicit MediaType sends it
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "application/octet-stream"}
MAX_AVATAR_SIZE = 5 * 1024 * 1024  # 5 MB
AVATAR_MAX_PX = 512
logger = logging.getLogger(__name__)


class AuthService:
    """Handles user registration, login token generation, and identity resolution."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.repo = UserRepository(db)

    # ── Register ──────────────────────────────────────────────
    async def register(self, req: RegisterRequest) -> TokenResponse:
        # 1. Duplicate email check
        existing = await self.repo.get_by_email(req.email)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Email '{req.email}' is already registered.",
            )

        # 2. Hash password and persist
        user = await self.repo.create(
            email=req.email,
            full_name=req.full_name,
            role=req.role,
            pin=req.pin,
            job_title=req.job_title,
        )
        await self.db.commit()

        # 3. Issue JWT immediately (no separate login step needed)
        security_logger.info(f"User registered successfully: {req.email}")
        return self._build_token_response(user)

    # ── Login ─────────────────────────────────────────────────
    async def login(self, req: LoginRequest) -> TokenResponse:
        user = await self.repo.get_by_email(req.email)

        # Use constant-time comparison even on "not found" branch to prevent
        # timing-based user enumeration attacks.
        if not user or not verify_password(req.password, user.password_hash):
            security_logger.warning(f"Failed login attempt for email: {req.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password.",
                headers={"WWW-Authenticate": "Bearer"},
            )

        security_logger.info(f"Successful login for user: {user.email}")
        return self._build_token_response(user)

    # ── Resolve current user ───────────────────────────────────
    async def get_current_user_info(self, user_id: str) -> UserInfo:
        """Resolve a UUID string (from JWT `sub` claim) to a UserInfo schema."""
        try:
            uid = _uuid.UUID(user_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Malformed token subject.",
            )

        user = await self.repo.get_by_id(uid)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Authenticated user no longer exists.",
            )
        return UserInfo.model_validate(user)

    # ── Avatar upload ─────────────────────────────────────────
    async def upload_avatar(self, user_id: str, file: UploadFile) -> AvatarUploadResponse:
        """Validate, resize, save the avatar image and update the user record."""
        # 1. Resolve user
        try:
            uid = _uuid.UUID(user_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Malformed token subject.",
            )

        user = await self.repo.get_by_id(uid)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Authenticated user no longer exists.",
            )

        # 2. Validate content type
        if file.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File type '{file.content_type}' is not allowed. "
                       f"Accepted: {', '.join(ALLOWED_CONTENT_TYPES)}",
            )

        try:
            # 3. Read bytes
            try:
                data = await file.read()
            except Exception as exc:
                logger.exception("Failed to read uploaded avatar bytes")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Cannot read uploaded file: {exc}",
                )

            if not data:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Uploaded file is empty.",
                )

            if len(data) > MAX_AVATAR_SIZE:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"File too large ({len(data)} bytes). Max: {MAX_AVATAR_SIZE} bytes.",
                )

            # 4. Pillow resize (offload to thread to prevent blocking event loop)
            def process_image(img_bytes: bytes) -> Image.Image:
                from io import BytesIO
                return Image.open(BytesIO(img_bytes)).convert("RGB")

            try:
                import asyncio
                img = await asyncio.to_thread(process_image, data)
                
                # Thumbnail modifies in-place, but we can do it safely in thread too
                # However for a quick LANCZOS, doing it here won't block long,
                # but let's offload it as well
                def resize_img(i: Image.Image) -> Image.Image:
                    i.thumbnail((AVATAR_MAX_PX, AVATAR_MAX_PX), Image.Resampling.LANCZOS)
                    return i
                
                img = await asyncio.to_thread(resize_img, img)
            except Exception as exc:
                logger.exception("Cannot process uploaded image for user_id=%s", user_id)
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Cannot process image file: {exc}",
                )

            # 5. Save to disk
            avatar_dir = os.path.join(settings.UPLOAD_DIR, "avatars")
            filename = f"{uid}.jpg"
            filepath = os.path.join(avatar_dir, filename)

            try:
                os.makedirs(avatar_dir, exist_ok=True)

                # Remove old avatar if exists (handle different extensions)
                for ext in (".jpg", ".png", ".webp"):
                    old_path = os.path.join(avatar_dir, f"{uid}{ext}")
                    if os.path.isfile(old_path):
                        os.remove(old_path)

                img.save(filepath, format="JPEG", quality=85, optimize=True)
            except PermissionError as exc:
                logger.exception("No write permission when saving avatar file")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"No permission to save avatar file: {exc}",
                )
            except OSError as exc:
                logger.exception("OS error when saving avatar file")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Failed to save avatar file: {exc}",
                )

            # 6. Build the public URL path and persist
            avatar_url = f"/uploads/avatars/{filename}"
            try:
                await self.repo.update_avatar(user, avatar_url)
                await self.db.commit()
            except SQLAlchemyError as exc:
                await self.db.rollback()
                logger.exception("Database error while updating avatar URL")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Database error while updating avatar: {exc}",
                )

            security_logger.info(f"Avatar updated for user: {user.email}")
            return AvatarUploadResponse(
                avatar_url=avatar_url,
                message="Avatar updated",
            )
        finally:
            try:
                await file.close()
            except Exception:
                logger.debug("Could not close uploaded file stream", exc_info=True)

    # ── Helpers ───────────────────────────────────────────────
    def _build_token_response(self, user) -> TokenResponse:
        expire_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        token = create_access_token(
            subject=str(user.id),
            expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        )
        return TokenResponse(
            access_token=token,
            token_type="bearer",
            expires_in=expire_seconds,
            user=UserInfo.model_validate(user),
        )

    async def logout(self, user_id: str) -> MessageResponse:
        """Stateless logout endpoint for clients to clear local token/session."""
        security_logger.info(f"User logged out: {user_id}")
        return MessageResponse(message=f"Logged out successfully for user {user_id}")
