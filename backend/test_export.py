import asyncio
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import SessionLocal
from app.services.face_service import FaceService

async def main():
    async with SessionLocal() as db:
        service = FaceService(db)
        print("Testing export_all...")
        res = await service.export_all()
        print(f"Result count: {len(res)}")

asyncio.run(main())
