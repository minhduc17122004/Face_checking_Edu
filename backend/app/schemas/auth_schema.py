from __future__ import annotations
"""Authentication schemas — login, register, token, and user-info responses."""
import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


# ──────────────────────────────────────────────────────────────
# Requests
# ──────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    """POST /auth/login — accepts email + password."""

    email: EmailStr = Field(..., examples=["teacher@school.edu"])
    password: str = Field(..., min_length=4, examples=["secret123"])


class RegisterRequest(BaseModel):
    """POST /auth/register — creates a new user account."""

    email: EmailStr = Field(..., examples=["teacher@school.edu"])
    password: str = Field(..., min_length=6, examples=["secret123"])
    full_name: str = Field(..., min_length=1, max_length=255, examples=["Nguyễn Văn A"])
    role: str = Field(
        default="student",
        pattern="^(teacher|student|admin)$",
        examples=["teacher"],
    )


# ──────────────────────────────────────────────────────────────
# Responses
# ──────────────────────────────────────────────────────────────
class UserInfo(BaseModel):
    """Lightweight user payload embedded inside token responses and /auth/me."""

    id: uuid.UUID
    email: EmailStr
    full_name: str
    role: str
    avatar_url: str | None = None
    created_at: datetime
    student_code: str | None = None
    class_name: str | None = None

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    """POST /auth/login — JWT bearer token + basic user info."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int = Field(..., description="Lifetime in seconds")
    user: UserInfo


class MessageResponse(BaseModel):
    """Generic message response for lightweight endpoints (e.g. logout)."""

    message: str


class AvatarUploadResponse(BaseModel):
    """POST /auth/avatar — response after successful avatar upload."""

    avatar_url: str
    message: str = "Avatar updated successfully"
