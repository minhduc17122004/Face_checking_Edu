from __future__ import annotations
"""In-memory cache service for high-frequency read data.

Provides TTL-based caching for:
- Active session state
- Student enrollment lists
- Course attendance config

Uses a simple dict + TTL approach (no Redis required).
"""
import asyncio
import time
from typing import Any, Callable, TypeVar, Awaitable

T = TypeVar("T")


class CacheEntry:
    """Single cache entry with TTL."""

    __slots__ = ("value", "expires_at")

    def __init__(self, value: Any, ttl_seconds: int) -> None:
        self.value = value
        self.expires_at = time.time() + ttl_seconds

    def is_expired(self) -> bool:
        return time.time() > self.expires_at


class CacheService:
    """Simple in-memory cache with TTL support.

    Thread-safe for asyncio via asyncio.Lock.
    """

    TTL_SHORT = 60      # 1 min  — session state, device status
    TTL_MEDIUM = 300   # 5 min  — student enrollment lists
    TTL_LONG = 3600    # 1 hour — course attendance config

    def __init__(self) -> None:
        self._store: dict[str, CacheEntry] = {}
        self._locks: dict[str, asyncio.Lock] = {}
        self._global_lock = asyncio.Lock()

    def _make_key(self, prefix: str, *args: Any) -> str:
        parts = [prefix]
        for a in args:
            if hasattr(a, "hex"):
                parts.append(a.hex)
            else:
                parts.append(str(a))
        return ":".join(parts)

    async def get(self, key: str) -> Any | None:
        """Get cached value if not expired."""
        entry = self._store.get(key)
        if entry is None:
            return None
        if entry.is_expired():
            del self._store[key]
            return None
        return entry.value

    async def set(self, key: str, value: Any, ttl: int) -> None:
        """Set a cache value with TTL in seconds."""
        self._store[key] = CacheEntry(value, ttl)

    async def delete(self, key: str) -> None:
        """Delete a cache entry."""
        self._store.pop(key, None)

    async def get_or_set(
        self,
        key: str,
        factory: Callable[[], Awaitable[T]],
        ttl: int,
    ) -> T:
        """Get from cache, or call factory and cache the result."""
        cached = await self.get(key)
        if cached is not None:
            return cached

        async with self._global_lock:
            # Double-check after acquiring lock
            cached = await self.get(key)
            if cached is not None:
                return cached

            value = await factory()
            await self.set(key, value, ttl)
            return value

    async def invalidate_prefix(self, prefix: str) -> None:
        """Remove all entries whose key starts with prefix."""
        keys_to_delete = [k for k in self._store if k.startswith(prefix)]
        for k in keys_to_delete:
            del self._store[k]

    async def clear(self) -> None:
        """Clear all cache entries."""
        self._store.clear()


# Singleton instance
_cache: CacheService | None = None


def get_cache() -> CacheService:
    global _cache
    if _cache is None:
        _cache = CacheService()
    return _cache
