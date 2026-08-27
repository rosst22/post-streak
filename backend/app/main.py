from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import get_settings
from app.database import engine
from app.routers import account, feed, friends, legal, moderation, posts, stats


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    yield
    await engine.dispose()


app = FastAPI(
    title="Post Streak API",
    version="0.1.0",
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)

settings = get_settings()
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(posts.router)
app.include_router(moderation.router)
app.include_router(stats.router)
app.include_router(account.router)
app.include_router(feed.router)
app.include_router(friends.router)
app.include_router(legal.router)


@app.get("/health", tags=["operations"])
async def health() -> dict[str, str]:
    # This is the only public route so Caddy/systemd can monitor the service.
    async with engine.connect() as connection:
        await connection.execute(text("select 1"))
    return {"status": "ok"}
