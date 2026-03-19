from __future__ import annotations

"""Auth router — POST /auth/register, POST /auth/login, GET /auth/me, POST /auth/avatar."""


import logging
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.core.security import get_current_user_id
from app.schemas.auth_schema import (
    RegisterRequest, LoginRequest, TokenResponse, UserInfo,
    MessageResponse, AvatarUploadResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])
logger = logging.getLogger(__name__)


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=201,
    summary="Register a new user account",
)
async def register(
    body: RegisterRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Create a new user (teacher / student / admin) and return a JWT token."""
    return await AuthService(db).register(body)


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Login and receive a JWT token",
)
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Authenticate with email + password and receive a bearer token."""
    return await AuthService(db).login(body)


@router.get(
    "/me",
    response_model=UserInfo,
    summary="Get the currently authenticated user",
)
async def me(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> UserInfo:
    """Return the profile of the user identified by the bearer token."""
    return await AuthService(db).get_current_user_info(user_id)


@router.post(
    "/avatar",
    response_model=AvatarUploadResponse,
    summary="Upload or update user avatar",
)
async def upload_avatar(
    avatar: Optional[UploadFile] = File(
        default=None,
        alias="avatar",
        description="Avatar image (field name 'avatar')",
    ),
    file: Optional[UploadFile] = File(
        default=None,
        alias="file",
        description="Avatar image (field name 'file')",
    ),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> AvatarUploadResponse:
    """Upload an image to set as the authenticated user's avatar.

    The image will be resized to 512×512 max and stored as JPEG.
    """
    selected_file = avatar or file
    if selected_file is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing file in multipart form-data. Use field name 'avatar' or 'file'.",
        )

    try:
        return await AuthService(db).upload_avatar(user_id, selected_file)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Unexpected error in /auth/avatar")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload avatar: {exc}",
        )


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Logout current user",
)
async def logout(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """Stateless logout endpoint so clients can synchronize sign-out flow."""
    return await AuthService(db).logout(user_id)
