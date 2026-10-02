"""Unit tests for the users API using FastAPI's TestClient."""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_list_users():
    res = client.get("/users")
    assert res.status_code == 200
    body = res.json()
    assert isinstance(body, list)
    assert len(body) >= 1


def test_create_user():
    res = client.post("/users", json={"name": "Carol", "email": "carol@example.com"})
    assert res.status_code == 201
    body = res.json()
    assert body["name"] == "Carol"
    assert isinstance(body["id"], int)


def test_create_user_rejects_bad_email():
    res = client.post("/users", json={"name": "Dave", "email": "invalid"})
    assert res.status_code == 400
