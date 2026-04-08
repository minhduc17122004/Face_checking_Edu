import asyncio
import asyncpg
from dotenv import dotenv_values

async def clear_faces():
    # Load env vars from .env
    config = dotenv_values(".env")
    database_url = config.get("DATABASE_URL")
    
    if not database_url:
        print("DATABASE_URL not found in .env")
        return

    # asyncpg expects postgresql:// instead of postgresql+asyncpg://
    database_url = database_url.replace("postgresql+asyncpg://", "postgresql://")

    print(f"Connecting to {database_url}...")
    try:
        conn = await asyncpg.connect(database_url)
        print("Connected.")
        
        # Execute TRUNCATE
        await conn.execute("TRUNCATE TABLE face_embeddings CASCADE;")
        print("Successfully truncated table face_embeddings.")
        
        await conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(clear_faces())
