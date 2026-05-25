"""Application settings for the Mops-API."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Settings loaded from environment variables and `.env`."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    api_host: str = "0.0.0.0"
    api_port: int = 8080

    ollama_host: str = "http://127.0.0.1:11434"
    ollama_model: str = "phi3:mini"
    ollama_timeout_seconds: int = 180

    cors_allow_origin_regex: str = (
        r"^https?://(localhost|127\.0\.0\.1"
        r"|192\.168\.\d+\.\d+"
        r"|10\.\d+\.\d+\.\d+"
        r"|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?$"
    )

    # Qdrant (lokale Instanz fuer Prof-Echos / Memory)
    qdrant_url: str = "http://localhost:6333"

    log_level: str = "INFO"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return cached Settings instance."""
    return Settings()
