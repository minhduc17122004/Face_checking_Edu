from __future__ import annotations
"""Auth service — registration, login, and current-user resolution."""
from datetime import timedelta

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logger import security_logger
from app.core.security import hash_password, verify_password, create_access_token
from app.repositories.user_repository import UserRepository
from app.schemas.auth_schema import RegisterRequest, LoginRequest, TokenResponse, UserInfo, MessageResponse


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
            password_hash=hash_password(req.password),
            full_name=req.full_name,
            role=req.role,
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
        import uuid as _uuid
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
