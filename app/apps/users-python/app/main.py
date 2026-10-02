"""Users REST API (Python + FastAPI) - DevOps lab App B.

The `app` object is importable by tests without opening a network port.

Phase 3 CI/CD trigger: pipeline smoke test (v3 - EKS access fixed).
"""
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

app = FastAPI(title="users-python", version="1.0.0")

_STATIC_DIR = Path(__file__).resolve().parent / "static"


class UserIn(BaseModel):
    name: str = Field(min_length=1)
    email: str = Field(min_length=3)


class User(UserIn):
    id: int


# In-memory data store (lab only - resets on restart).
_users: list[User] = [
    User(id=1, name="Alice", email="alice@example.com"),
    User(id=2, name="Bob", email="bob@example.com"),
]
_next_id = 3


@app.get("/", include_in_schema=False)
def home() -> FileResponse:
    """Serve the GUI landing page."""
    return FileResponse(_STATIC_DIR / "index.html")


@app.get("/health")
def health() -> dict:
    """Health check - used by Kubernetes liveness/readiness probes later."""
    return {"status": "ok"}


@app.get("/users")
def list_users() -> list[User]:
    return _users


@app.post("/users", status_code=201)
def create_user(payload: UserIn) -> User:
    global _next_id
    if "@" not in payload.email:
        raise HTTPException(status_code=400, detail="email must contain @")
    user = User(id=_next_id, name=payload.name, email=payload.email)
    _next_id += 1
    _users.append(user)
    return user
