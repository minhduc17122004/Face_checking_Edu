from datetime import datetime, timedelta, timezone
from typing import Optional, Any

from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from app.core.config import settings

# ──────────────────────────────────────────────────────────────
# Password hashing
# ──────────────────────────────────────────────────────────────
# Prefer bcrypt_sha256 to avoid bcrypt backend edge cases and 72-byte limits.
# Keep bcrypt as a fallback so existing hashes can still be verified.
pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    """Hash a plain-text password using bcrypt."""
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plain-text password against a bcrypt hash."""
    return pwd_context.verify(plain, hashed)


# ──────────────────────────────────────────────────────────────
# JWT token utilities
# ──────────────────────────────────────────────────────────────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def create_access_token(
    subject: Any,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Create a signed JWT access token.

    Args:
        subject: The value to embed as `sub` claim (typically user UUID as str).
        expires_delta: Token lifetime; falls back to settings default.
    """
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload = {"sub": str(subject), "exp": expire, "iat": datetime.now(timezone.utc)}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Decode and verify a JWT. Raises HTTPException on failure."""
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


# ──────────────────────────────────────────────────────────────
# FastAPI dependency: get current user from bearer token
# ──────────────────────────────────────────────────────────────
async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
    """Extract and return the authenticated user's UUID string from the token.

    This is a lightweight dependency.  Routers that need the full User ORM
    object should layer an additional dependency on top of this one.
    """
    payload = decode_access_token(token)
    return payload["sub"]
