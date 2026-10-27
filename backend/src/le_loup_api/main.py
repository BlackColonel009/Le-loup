"""HTTP/WebSocket gateway for the authoritative Dart game engine."""

import asyncio
import contextlib
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

from .administration import router as admin_router
from .community import Store
from .community import router as community_router
from .online import Rooms, router
from .profile import router as profile_router
from .shop import router as shop_router


@asynccontextmanager
async def lifespan(app):
    app.state.rooms = Rooms()
    app.state.community = Store(
        os.getenv(
            "LE_LOUP_COMMUNITY_DB",
            str(Path(__file__).resolve().parents[2] / "data/community.sqlite3"),
        )
    )
    reaper = asyncio.create_task(app.state.rooms.reap())
    try:
        yield
    finally:
        reaper.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await reaper
        await app.state.rooms.close()


app = FastAPI(title="Legende of Wolf API", version="0.2.0", lifespan=lifespan)
app.include_router(router)
app.include_router(community_router)
app.include_router(shop_router)
app.include_router(admin_router)
app.include_router(profile_router)


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "le-loup-api", "protocol": "1"}
