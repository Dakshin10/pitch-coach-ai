"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import logging

from config import get_settings
from limiter import limiter
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from firestore import get_db  # noqa: F401 — initialises Firebase on first import
from auth.router import router as auth_router
from users.router import router as users_router
from sessions.router import router as sessions_router, sweep_stuck_sessions
from stats.router import router as stats_router
from achievements.router import router as achievements_router
from slides.router import router as slides_router
from slides.store import deck_store

logger = logging.getLogger(__name__)
settings = get_settings()

app = FastAPI(
    title="Pitch Coach API",
    version="2.0.0",
    description="Backend API for the Pitch Coach Flutter app — powered by Firebase Firestore.",
)


@app.on_event("startup")
async def on_startup():
    try:
        swept_decks = deck_store.sweep_stuck_decks()
        swept_sessions = sweep_stuck_sessions()
        logger.info("Startup sweep: recovered %d stuck decks and %d stuck sessions", swept_decks, swept_sessions)
    except Exception as exc:
        logger.warning("Startup stuck job sweep failed: %s", exc)

# Attach rate limiter
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(sessions_router)
app.include_router(stats_router)
app.include_router(achievements_router)
app.include_router(slides_router)


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok", "version": "2.0.0", "db": "firestore"}
