from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "sqlite:///./pitch_coach.db"

    # JWT
    SECRET_KEY: str = "change-me-in-production-use-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24   # 1 day
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Groq (used for both Whisper STT and LLaMA LLM)
    GROQ_API_KEY: str = ""

    # Audio file storage (local disk for v1)
    AUDIO_UPLOAD_DIR: str = "./audio_files"

    # Guest account expiry
    GUEST_EXPIRE_DAYS: int = 30

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
