import asyncio
import os
import sys

# Add the backend directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.database import AsyncSessionLocal
from sqlalchemy import delete
from app.models.face_embedding import FaceEmbedding

async def clear_faces():
    async with AsyncSessionLocal() as db:
        result = await db.execute(delete(FaceEmbedding))
        deleted_count = result.rowcount
        await db.commit()
        print(f"All face embeddings deleted successfully. Total deleted rows: {deleted_count}")

if __name__ == "__main__":
    asyncio.run(clear_faces())
