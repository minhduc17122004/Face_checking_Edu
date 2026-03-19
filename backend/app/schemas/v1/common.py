from __future__ import annotations
"""Common schemas — pagination and shared response types."""
from pydantic import BaseModel, Field
from typing import Generic, TypeVar

T = TypeVar("T")


class PaginationParams:
    """Standard pagination query params for list endpoints."""

    skip: int = Field(0, ge=0, description="Number of records to skip")
    limit: int = Field(50, ge=1, le=500, description="Max records to return")


class PaginatedResponse(BaseModel, Generic[T]):
    """Standard paginated list response."""
    total: int = Field(..., description="Total number of matching records")
    skip: int = Field(..., description="Records skipped")
    limit: int = Field(..., description="Page size")
    items: list[T] = Field(..., description="Records in this page")


class ErrorDetail(BaseModel):
    """Standard error response."""
    message: str
    detail: str | None = None
