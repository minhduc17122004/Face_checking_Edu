from __future__ import annotations
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_register(client: AsyncClient):
    resp = await client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "password123",
        "full_name": "Test User",
        "role": "student"
    })
    assert resp.status_code == 201
    assert "access_token" in resp.json()

    resp2 = await client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "password123",
        "full_name": "Test User",
        "role": "student"
    })
    assert resp2.status_code == 409

@pytest.mark.asyncio
async def test_login_and_me(client: AsyncClient):
    resp = await client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "password123"
    })
    assert resp.status_code == 200, resp.json()
    token = resp.json()["access_token"]
    
    resp2 = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert resp2.status_code == 200
    assert resp2.json()["email"] == "test@example.com"
    
    resp3 = await client.post("/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert resp3.status_code == 200

@pytest.mark.asyncio
async def test_login_rate_limiting(client: AsyncClient):
    hit_rate_limit = False
    for _ in range(10):
        resp = await client.post("/auth/login", json={
            "email": "test@example.com",
            "password": "password123"
        })
        if resp.status_code == 429:
            hit_rate_limit = True
            break
        assert resp.status_code == 200, resp.json()

    assert hit_rate_limit, "Did not hit rate limit"
