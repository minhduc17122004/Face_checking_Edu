from __future__ import annotations
"""Distributed lock service for preventing concurrent check-in on the same session/student.

Phase 9: Uses Redis to provide distributed mutual exclusion across multiple workers.
Falls back gracefully when Redis is not available.
"""
import asyncio
import uuid
import logging
from contextlib import asynccontextmanager
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import redis.asyncio as redis

logger = logging.getLogger(__name__)

# ── Redis client (lazy initialization) ─────────────────────────────────────────
_redis_client: "redis.Redis | None" = None


async def get_redis() -> "redis.Redis | None":
    """Get or create Redis client. Returns None if Redis is unavailable."""
    global _redis_client
    if _redis_client is not None:
        try:
            await _redis_client.ping()
            return _redis_client
        except Exception:
            _redis_client = None
            return None

    try:
        import redis.asyncio as redis
        from app.core.config import settings

        _redis_client = redis.Redis(
            host=settings.REDIS_HOST or "localhost",
            port=settings.REDIS_PORT or 6379,
            db=settings.REDIS_DB or 0,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        await _redis_client.ping()
        return _redis_client
    except Exception as exc:
        logger.warning("Redis unavailable: %s. Distributed locks disabled.", exc)
        _redis_client = None
        return None


async def close_redis() -> None:
    """Close Redis connection on shutdown."""
    global _redis_client
    if _redis_client is not None:
        await _redis_client.close()
        _redis_client = None


# ── Lock exception ─────────────────────────────────────────────────────────────


class LockAcquisitionError(Exception):
    """Raised when a distributed lock cannot be acquired."""

    pass


# ── Distributed lock implementation ───────────────────────────────────────────


class DistributedLock:
    """Redis-based distributed lock using SET NX with TTL.

    Usage:
        lock = DistributedLock(key="checkin:session1:student1", ttl_seconds=30)
        await lock.acquire()
        try:
            # critical section
        finally:
            await lock.release()
    """

    LOCK_PREFIX = "dlk:"

    def __init__(self, key: str, ttl_seconds: int = 30) -> None:
        self.key = f"{self.LOCK_PREFIX}{key}"
        self.ttl = ttl_seconds
        self.holder_id = str(uuid.uuid4())
        self._acquired = False

    async def acquire(self, timeout_seconds: float = 5.0) -> None:
        """Acquire the lock with optional timeout.

        Raises LockAcquisitionError if lock cannot be acquired within timeout.
        """
        redis = await get_redis()
        if redis is None:
            # No Redis — skip locking (fallback to no-op)
            self._acquired = False
            return

        import time as time_module

        deadline = time_module.monotonic() + timeout_seconds
        while time_module.monotonic() < deadline:
            acquired = await redis.set(
                self.key,
                self.holder_id,
                nx=True,  # only set if not exists
                ex=self.ttl,  # expire after TTL
            )
            if acquired:
                self._acquired = True
                logger.debug("Lock acquired: %s (holder=%s)", self.key, self.holder_id)
                return

            await asyncio.sleep(0.05)  # 50ms retry interval

        raise LockAcquisitionError(
            f"Failed to acquire lock '{self.key}' within {timeout_seconds}s"
        )

    async def release(self) -> None:
        """Release the lock (only if we are the holder)."""
        if not self._acquired:
            return

        redis = await get_redis()
        if redis is None:
            self._acquired = False
            return

        # Lua script: only delete if value matches (prevents releasing someone else's lock)
        script = """
        if redis.call("get", KEYS[1]) == ARGV[1] then
            return redis.call("del", KEYS[1])
        else
            return 0
        end
        """
        try:
            result = await redis.eval(script, 1, self.key, self.holder_id)
            if result:
                logger.debug("Lock released: %s", self.key)
        except Exception as exc:
            logger.warning("Error releasing lock %s: %s", self.key, exc)
        finally:
            self._acquired = False


@asynccontextmanager
async def checkin_lock(
    session_id: uuid.UUID,
    student_id: int,
    timeout_seconds: float = 5.0,
    ttl_seconds: int = 30,
):
    """Async context manager for distributed check-in lock.

    Ensures only one process can process a check-in for a given
    session/student pair at a time, even under high concurrency.

    Usage:
        async with checkin_lock(session_id, student_id):
            await attendance_service.create_attendance(...)

    Raises LockAcquisitionError if lock cannot be acquired.
    """
    lock_key = f"checkin:{session_id}:{student_id}"
    lock = DistributedLock(key=lock_key, ttl_seconds=ttl_seconds)
    await lock.acquire(timeout_seconds=timeout_seconds)
    try:
        yield
    finally:
        await lock.release()
