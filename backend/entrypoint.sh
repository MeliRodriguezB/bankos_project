#!/bin/sh
set -eu

# Register ORM models and create any missing tables before applying versioned migrations.
python - <<'PY'
import app.main
from app.db.base import Base
from app.db.session import engine

Base.metadata.create_all(bind=engine)
PY

# Apply idempotent schema changes before starting the API.
alembic upgrade head

exec uvicorn app.main:app --host 0.0.0.0 --port 8000
