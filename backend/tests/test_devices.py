from __future__ import annotations
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_register_device(client: AsyncClient):
    resp = await client.post("/devices/register", json={
        "device_code": "kiosk-01",
        "room": "A101"
    })
    assert resp.status_code == 201
    assert resp.json()["device_code"] == "kiosk-01"
    
    # Duplicate device code
    resp2 = await client.post("/devices/register", json={
        "device_code": "kiosk-01",
        "room": "B202"
    })
    assert resp2.status_code == 400

@pytest.mark.asyncio
async def test_device_schedule(client: AsyncClient):
    resp = await client.get("/devices/A101/schedule/today")
    assert resp.status_code == 200
    assert resp.json()["room"] == "A101"
    assert len(resp.json()["schedule"]) > 0
