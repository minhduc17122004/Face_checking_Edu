from __future__ import annotations
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://vedura:vedura_pass@db:5432/vedura_db"

    # JWT
    SECRET_KEY: str = "changeme-super-secret-key-please-update-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15       # Short-lived: 15 minutes
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7          # Long-lived: 7 days

    # File uploads
    UPLOAD_DIR: str = "uploads"

    # App
    APP_NAME: str = "Vedura Face Attendance API"
    DEBUG: bool = False
    CORS_ORIGINS: list = ["*"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
