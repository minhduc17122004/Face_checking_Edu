from __future__ import annotations
import logging
import sys
import json

# Configure a specific logger for security events
security_logger = logging.getLogger("security")
security_logger.setLevel(logging.INFO)

# Avoid adding multiple handlers if the logger is re-initialized
if not security_logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.INFO)
    
    # We use a specific format for security events to make them easy to parse
    formatter = logging.Formatter(
        fmt="%(asctime)s - SECURITY - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)
    
    security_logger.addHandler(handler)
    security_logger.propagate = False # don't pass to root logger to avoid duplicates
