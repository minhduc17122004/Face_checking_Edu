"""Auth router — POST /auth/register, POST /auth/login, GET /auth/me."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import get_current_user_id
from app.schemas.auth_schema import RegisterRequest, LoginRequest, TokenResponse, UserInfo, MessageResponse
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Auth"])


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
