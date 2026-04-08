import asyncio
import traceback
from app.main import app
from httpx import AsyncClient

# Provide mock admin info to bypass Depends
async def mock_get_current_user_id() -> str:
    return "19c0116c-3b56-484e-a567-e0289afcf8a0"

app.dependency_overrides[app.router.dependencies[0].dependency] = mock_get_current_user_id

async def main():
    try:
        async with AsyncClient(app=app, base_url="http://test") as ac:
            req1 = await ac.get("/api/v1/courses/")
            print("Courses:", req1.status_code, req1.text)
            
            req2 = await ac.get("/api/v1/attendance/history?skip=0&limit=50")
            print("History:", req2.status_code, req2.text)
    except Exception as e:
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
