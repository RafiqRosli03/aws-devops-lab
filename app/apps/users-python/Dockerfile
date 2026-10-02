# ---- Stage 1: build dependencies ----
FROM python:3.12-slim AS build
WORKDIR /app

COPY requirements.txt .
# Install into an isolated prefix so we can copy just the runtime deps later
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: runtime (small, non-root) ----
FROM python:3.12-slim AS runtime
WORKDIR /app
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

# Copy installed packages from the build stage
COPY --from=build /install /usr/local
COPY app ./app

# Create and use a non-root user
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
# Use shell form so ${PORT} is expanded at runtime
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
