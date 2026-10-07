"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from firestore import get_db  # noqa: F401 — initialises Firebase on first import
from auth.router import router as auth_router
from users.router import router as users_router
from sessions.router import router as sessions_router
from stats.router import router as stats_router
from achievements.router import router as achievements_router

app = FastAPI(
    title="Pitch Coach API",
    version="2.0.0",
    description="Backend API for the Pitch Coach Flutter app — powered by Firebase Firestore.",
)

# Allow Flutter app on emulator (10.0.2.2) and physical device (LAN IP)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(sessions_router)
app.include_router(stats_router)
app.include_router(achievements_router)


@app.get("/health", tags=["health"])
def health_check():
    return {"status": "ok", "version": "2.0.0", "db": "firestore"}
