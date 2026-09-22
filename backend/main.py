"""FastAPI application entry point."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import Base, engine
from auth.router import router as auth_router
from users.router import router as users_router
from sessions.router import router as sessions_router
from stats.router import router as stats_router
from achievements.router import router as achievements_router

# Create all tables on startup (SQLite: creates the .db file if missing)
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Pitch Coach API",
    version="1.0.0",
    description="Backend API for the Pitch Coach Flutter app.",
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
    return {"status": "ok", "version": "1.0.0"}
