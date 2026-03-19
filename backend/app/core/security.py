from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Optional, Any
import uuid

from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.refresh_token import RefreshToken

# ──────────────────────────────────────────────────────────────
# Password hashing
# ──────────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ──────────────────────────────────────────────────────────────
# JWT token utilities
# ──────────────────────────────────────────────────────────────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def _build_payload(
    subject: Any,
    expires_delta: timedelta,
    extra_claims: dict | None = None,
) -> dict:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(subject),
        "exp": now + expires_delta,
        "iat": now,
        "jti": str(uuid.uuid4()),
    }
    if extra_claims:
        payload.update(extra_claims)
    return payload


def create_access_token(
    subject: Any,
    expires_delta: timedelta | None = None,
) -> str:
    expire = expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = _build_payload(subject, expire)
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(
    subject: str,
    expires_delta: timedelta | None = None,
) -> str:
    expire = expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = _build_payload(subject, expire, {"type": "refresh"})
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        sub: str = payload.get("sub")
        if sub is None:
            raise credentials_exception
        return payload
    except JWTError:
        raise credentials_exception


def decode_refresh_token(token: str) -> dict | None:
    """Decode refresh token. Returns None if invalid or expired."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        if payload.get("type") != "refresh":
            return None
        return payload
    except JWTError:
        return None


async def save_refresh_token(
    user_id: str,
    token: str,
    device_id: str | None = None,
) -> RefreshToken:
    """Hash and store a refresh token in the DB."""
    payload = decode_refresh_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    async with AsyncSessionLocal() as db:
        jti = payload.get("jti", str(uuid.uuid4()))
        expires_at = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        rt = RefreshToken(
            user_id=uuid.UUID(user_id),
            token_jti=jti,
            device_id=device_id,
            expires_at=expires_at,
        )
        db.add(rt)
        await db.commit()
        await db.refresh(rt)
        return rt


async def revoke_refresh_token(user_id: str, token: str) -> bool:
    """Revoke a specific refresh token by jti."""
    payload = decode_refresh_token(token)
    if not payload:
        return False
    jti = payload.get("jti")
    if not jti:
        return False
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(RefreshToken).where(
                RefreshToken.token_jti == jti,
                RefreshToken.user_id == uuid.UUID(user_id),
            )
        )
        rt = result.scalar_one_or_none()
        if rt:
            rt.revoked = True
            await db.commit()
            return True
        return False


async def revoke_all_user_tokens(user_id: str) -> int:
    """Revoke ALL refresh tokens for a user. Returns count of revoked tokens."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == uuid.UUID(user_id),
                RefreshToken.revoked == False,  # noqa: E712
            )
        )
        tokens = result.scalars().all()
        count = 0
        for t in tokens:
            t.revoked = True
            count += 1
        await db.commit()
        return count


async def is_token_revoked(user_id: str, token: str) -> bool:
    """Check if a refresh token has been revoked."""
    payload = decode_refresh_token(token)
    if not payload:
        return True
    jti = payload.get("jti")
    if not jti:
        return True
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(RefreshToken).where(
                RefreshToken.token_jti == jti,
                RefreshToken.user_id == uuid.UUID(user_id),
            )
        )
        rt = result.scalar_one_or_none()
        if not rt:
            return True
        return rt.revoked


# ──────────────────────────────────────────────────────────────
# FastAPI dependency: get current user from bearer token
# ──────────────────────────────────────────────────────────────
async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
    """Extract and return the authenticated user's UUID string from the token."""
    payload = decode_access_token(token)
    return payload["sub"]
