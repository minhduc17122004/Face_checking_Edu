from __future__ import annotations
import logging
import sys
import json
from datetime import datetime, timezone

# ── Application logger (structured logging via JSON) ───────────────────────────
class _StructuredFormatter(logging.Formatter):
    """JSON formatter for structured log output."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        # Attach extra fields if present
        for key, value in vars(record).items():
            if key not in ("name", "msg", "args", "created", "filename",
                           "funcName", "levelname", "lineno", "module",
                           "msecs", "pathname", "process", "processName",
                           "relativeCreated", "stack_info", "exc_info",
                           "exc_text", "thread", "threadName", "message"):
                log_entry[key] = value
        return json.dumps(log_entry)


def _setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(level)
        handler.setFormatter(_StructuredFormatter())
        logger.addHandler(handler)
        logger.propagate = False
    return logger


# Main application logger
app_logger = _setup_logger("app", logging.INFO)

# Security event logger
security_logger = _setup_logger("security", logging.INFO)

# Audit logger
audit_logger = _setup_logger("audit", logging.INFO)


def log_info(logger: logging.Logger, msg: str, **kwargs) -> None:
    """Log an info message with structured extra fields."""
    logger.info(msg, extra=kwargs)


def log_error(logger: logging.Logger, msg: str, **kwargs) -> None:
    """Log an error message with structured extra fields."""
    logger.error(msg, extra=kwargs)


def log_warning(logger: logging.Logger, msg: str, **kwargs) -> None:
    """Log a warning message with structured extra fields."""
    logger.warning(msg, extra=kwargs)

