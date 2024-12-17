# Define a base stage with a Debian Bookworm base image
FROM python:3.12-bookworm as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_NO_CACHE_DIR=true \
    PIP_DEFAULT_TIMEOUT=100 \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    QR_CODE_DIR=/myapp/qr_codes

WORKDIR /myapp

# Update system and install required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libc-bin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies in /.venv
COPY requirements.txt ./
RUN python -m venv /.venv \
    && . /.venv/bin/activate \
    && pip install --upgrade pip \
    && pip install -r requirements.txt

# Define a second stage for the runtime, using a slim Bookworm base image
FROM python:3.12-slim-bookworm as final

# Copy the virtual environment from the base stage
COPY --from=base /.venv /.venv

# Set environment variable to ensure all python commands run inside the virtual environment
ENV PATH="/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    QR_CODE_DIR=/myapp/qr_codes

# Set the working directory
WORKDIR /myapp

# Create and switch to a non-root user
RUN useradd -m myuser
USER myuser

# Copy application code with appropriate ownership
COPY --chown=myuser:myuser . ./

# Use a .dockerignore file to avoid copying unnecessary files
# Example .dockerignore content:
# .git
# __pycache__
# *.log

# Inform Docker that the container listens on the specified port
EXPOSE 8000

# Use ENTRYPOINT to specify the executable when the container starts
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
