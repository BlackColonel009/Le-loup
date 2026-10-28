"""HTTP/WebSocket gateway for the authoritative Dart game engine."""

import asyncio
import contextlib
import os
from contextlib import asynccontextmanager
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI

from .account_deletion import router as deletion_router
from .administration import router as admin_router
from .community import Store
from .community import router as community_router
from . import community_mail
from .content_packs import router as content_router
from .content_packs import initialize as initialize_content
from . import social, social_scheduler
from . import collection
from .gallery import initialize as initialize_gallery
from .gallery import router as gallery_router
from .online import Rooms, router
from .profile import router as profile_router
from .shop import router as shop_router
from .website import install as install_website


@asynccontextmanager
async def lifespan(app):
    load_dotenv(Path(__file__).resolve().parents[2] / ".env", override=False)
    initialize_content()
    app.state.rooms = Rooms()
    app.state.community = Store(
        os.getenv(
            "MORDEVIEL_COMMUNITY_DB",
            str(Path(__file__).resolve().parents[2] / "data/community.sqlite3"),
        )
    )
    initialize_gallery(app.state.community)
    social.initialize(app.state.community)
    collection.initialize(app.state.community)
    app.state.rooms.db = app.state.community
    social_task = asyncio.create_task(social_scheduler.run(app.state.community, app.state.rooms))
    community_mail.initialize(app.state.community)
    mailer = asyncio.create_task(community_mail.run(app.state.community))
    reaper = asyncio.create_task(app.state.rooms.reap())
    try:
        yield
    finally:
        social_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await social_task
        mailer.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await mailer
        reaper.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await reaper
        await app.state.rooms.close()


app = FastAPI(title="Mordeviel API", version="0.2.0", lifespan=lifespan)
app.include_router(router)
app.include_router(community_router)
app.include_router(community_mail.router)
app.include_router(content_router)
app.include_router(social.router)
app.include_router(collection.router)
app.include_router(social_scheduler.router)
app.include_router(shop_router)
app.include_router(admin_router)
app.include_router(profile_router)
app.include_router(deletion_router)
app.include_router(gallery_router)
install_website(app)


@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "mordeviel-api", "protocol": "1"}
