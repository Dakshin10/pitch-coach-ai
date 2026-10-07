from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # JWT
    SECRET_KEY: str = "change-me-in-production-use-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24   # 1 day
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Groq key dedicated to the audio-analysis pipeline (Whisper STT + agentic coach).
    # Falls back to GROQ_API_KEY when empty.
    GROQ_AUDIO_API_KEY: str = ""
    GROQ_API_KEY: str = ""
    # Model names change often on Groq — override here without a code change.
    GROQ_WHISPER_MODEL: str = "whisper-large-v3-turbo"
    GROQ_LLM_MODEL: str = "llama-3.3-70b-versatile"

    # Firebase Admin SDK — path to service-account JSON
    FIREBASE_SERVICE_ACCOUNT_PATH: str = "./firebase_service_account.json"

    # Firebase Storage bucket for recordings, e.g. "<project-id>.firebasestorage.app"
    # (Firebase Console -> Storage shows the exact name).
    FIREBASE_STORAGE_BUCKET: str = ""

    # Uploads larger than this are rejected (recordings are small AAC files)
    MAX_AUDIO_UPLOAD_MB: int = 25

    # Guest account expiry
    GUEST_EXPIRE_DAYS: int = 30

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
