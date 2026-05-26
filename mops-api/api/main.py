"""FastAPI application entry point for the Mops-API."""

from __future__ import annotations

import sys
from contextlib import asynccontextmanager

from pathlib import Path

import psutil
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from loguru import logger

from api.config import Settings, get_settings
from api.routes import admin, chat, classify, health
from api.services.memory_service import MemoryService
from api.services.ollama_client import OllamaClient


def _configure_logging(level: str) -> None:
    logger.remove()
    logger.add(
        sys.stderr,
        level=level,
        format=(
            "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<cyan>{name}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
        ),
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise the Ollama client and prime psutil's CPU sampler."""
    settings = get_settings()
    _configure_logging(settings.log_level)
    logger.info(
        f"Starting Mops-API · ollama={settings.ollama_host} model={settings.ollama_model}"
    )

    # Prime psutil.cpu_percent() so the first /health/detailed has a real value.
    psutil.cpu_percent(interval=None)

    ollama = OllamaClient(
        host=settings.ollama_host,
        model=settings.ollama_model,
        timeout=settings.ollama_timeout_seconds,
    )
    if await ollama.health_check():
        logger.info("Ollama reachable.")
    else:
        logger.warning(
            "Ollama is not reachable on startup — /chat will return 502 until "
            "the server is up. Try: `systemctl status ollama`."
        )

    app.state.ollama = ollama

    # Memory-Service (Qdrant) fuer Prof-Echos initialisieren
    memory = MemoryService(qdrant_url=settings.qdrant_url)
    try:
        await memory.init_collections()
        logger.info("MemoryService initialisiert (Qdrant).")
    except Exception as exc:  # noqa: BLE001
        logger.warning(
            f"Qdrant nicht erreichbar — Admin-UI funktioniert erst wenn Qdrant laeuft: {exc}"
        )
    app.state.memory_service = memory

    yield
    logger.info("Mops-API shutting down.")


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build the FastAPI application."""
    settings = settings or get_settings()

    app = FastAPI(
        title="Mops-API",
        description=(
            "Lokales LLM-Backend fuer iMOPS Construction Grid. "
            "Baseline-Version ohne RAG — direkter Phi-3-Durchgriff."
        ),
        version="0.1.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=settings.cors_allow_origin_regex,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(chat.router)
    app.include_router(classify.router)
    app.include_router(admin.router)

    # Admin-UI als statische Dateien ausliefern
    static_dir = Path(__file__).resolve().parent.parent / "static"
    static_dir.mkdir(exist_ok=True)
    app.mount("/admin-ui", StaticFiles(directory=str(static_dir), html=True), name="admin")

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    s = get_settings()
    uvicorn.run("api.main:app", host=s.api_host, port=s.api_port, reload=False)
