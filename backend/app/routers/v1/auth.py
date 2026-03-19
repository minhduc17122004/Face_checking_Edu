from __future__ import annotations
"""v1 Auth router — /api/v1/auth endpoints."""
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import (
    get_current_user_id,
    create_access_token,
    create_refresh_token,
    save_refresh_token,
    revoke_all_user_tokens,
    revoke_refresh_token,
    decode_refresh_token,
)
from app.core.config import settings
from app.repositories.user_repository import UserRepository
from app.schemas.v1.auth import (
    LoginRequest,
    RegisterRequest,
    RefreshRequest,
    TokenResponse,
    UserInfo,
    MessageResponse,
    AvatarUploadResponse,
)

router = APIRouter(prefix="/auth", tags=["v1 — Auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new user account."""
    repo = UserRepository(db)
    existing = await repo.get_by_email(req.email)
    if existing:
        raise HTTPException(status_code=409, detail=f"Email '{req.email}' is already registered.")

    from app.core.security import hash_password
    user = await repo.create(
        email=req.email,
        password_hash=hash_password(req.password),
        full_name=req.full_name,
        role=req.role,
    )
    await db.commit()

    access_token = create_access_token(subject=str(user.id))
    refresh_token = create_refresh_token(subject=str(user.id))
    await save_refresh_token(str(user.id), refresh_token)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserInfo.model_validate(user),
    )


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Login and receive access + refresh tokens."""
    repo = UserRepository(db)
    user = await repo.get_by_email(req.email)

    from app.core.security import verify_password
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(subject=str(user.id))
    refresh_token = create_refresh_token(subject=str(user.id))
    await save_refresh_token(str(user.id), refresh_token)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserInfo.model_validate(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Refresh access token using a valid refresh token."""
    payload = decode_refresh_token(req.refresh_token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token.")

    user_id = payload.get("sub")
    user_repo = UserRepository(db)
    user = await user_repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found.")

    access_token = create_access_token(subject=str(user.id))
    new_refresh = create_refresh_token(subject=str(user.id))
    await save_refresh_token(str(user.id), new_refresh)

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        user=UserInfo.model_validate(user),
    )


@router.get("/me", response_model=UserInfo)
async def me(user_id: str = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    """Get current authenticated user info."""
    repo = UserRepository(db)
    user = await repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    return UserInfo.model_validate(user)


@router.post("/avatar", response_model=AvatarUploadResponse)
async def upload_avatar(
    file: UploadFile,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Upload and resize avatar (512px JPEG)."""
    from app.core.security import hash_password
    from app.core.logger import security_logger
    import os
    from PIL import Image
    from io import BytesIO

    ALLOWED = {"image/jpeg", "image/png", "image/webp", "application/octet-stream"}
    if file.content_type not in ALLOWED:
        raise HTTPException(status_code=400, detail="Unsupported file type.")

    data = await file.read()
    if len(data) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 5MB).")

    import asyncio

    def process():
        img = Image.open(BytesIO(data)).convert("RGB")
        img.thumbnail((512, 512))
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=85, optimize=True)
        return buf.getvalue()

    img_bytes = await asyncio.to_thread(process)

    import uuid as _uuid

    uid = _uuid.UUID(user_id)
    avatar_dir = os.path.join(settings.UPLOAD_DIR, "avatars")
    os.makedirs(avatar_dir, exist_ok=True)
    filepath = os.path.join(avatar_dir, f"{uid}.jpg")

    for ext in (".jpg", ".png", ".webp"):
        old = os.path.join(avatar_dir, f"{uid}{ext}")
        if os.path.isfile(old):
            os.remove(old)

    with open(filepath, "wb") as f:
        f.write(img_bytes)

    avatar_url = f"/uploads/avatars/{uid}.jpg"
    repo = UserRepository(db)
    user = await repo.get_by_id(uid)
    if user:
        await repo.update_avatar(user, avatar_url)

    security_logger.info(f"Avatar updated for user: {user.email}")
    return AvatarUploadResponse(avatar_url=avatar_url, message="Avatar updated")


@router.post("/logout", response_model=MessageResponse)
async def logout(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """Logout: revoke all refresh tokens for the user."""
    count = await revoke_all_user_tokens(user_id)
    return MessageResponse(message=f"Logged out. {count} token(s) revoked.")
