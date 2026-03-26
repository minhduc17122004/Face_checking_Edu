import asyncio
import sys

from sqlalchemy import select, and_

sys.path.append("c:/Users/ADMIN/Desktop/MIS/hrm-flutter_dev_2.0/hrm-flutter_dev_2.0/face_time_keeping/backend")

from dotenv import load_dotenv
load_dotenv(".env")

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from datetime import date
from app.services.session_generator_service import SessionGeneratorService

async def main():
    async with AsyncSessionLocal() as db:
        try:
            target_date = date(2026, 3, 26)
            svc = SessionGeneratorService(db)
            sessions = await svc.generate_sessions_for_date(target_date)
            print("Success")
            print([s.id for s in sessions])
        except Exception as e:
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
