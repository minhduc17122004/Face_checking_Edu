# ──────────────────────────────────────────────────────────────
# Vedura Backend Dockerfile
# ──────────────────────────────────────────────────────────────
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies required by some Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . .

# Ensure uploads directory exists and make entrypoint executable
RUN mkdir -p uploads \
    && chmod +x entrypoint.sh

# Expose API port
EXPOSE 8000

# Entrypoint: run Alembic migrations then start uvicorn
ENTRYPOINT ["./entrypoint.sh"]
