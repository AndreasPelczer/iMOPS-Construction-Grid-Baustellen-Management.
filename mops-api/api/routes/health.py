"""Health-check endpoints."""

from __future__ import annotations

import psutil
from fastapi import APIRouter, Request

from api.models import DetailedHealthResponse, HealthResponse
from api.services.ollama_client import OllamaClient

router = APIRouter(prefix="/health", tags=["health"])


def _ollama(request: Request) -> OllamaClient:
    return request.app.state.ollama


@router.get("", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    """Return basic liveness + Ollama reachability."""
    ollama = _ollama(request)
    reachable = await ollama.health_check()
    return HealthResponse(
        status="ok" if reachable else "degraded",
        ollama_reachable=reachable,
        model=ollama.model,
    )


@router.get("/detailed", response_model=DetailedHealthResponse)
async def health_detailed(request: Request) -> DetailedHealthResponse:
    """Return extended status: Ollama, model list, RAM, CPU, disk."""
    ollama = _ollama(request)
    reachable = await ollama.health_check()
    models = await ollama.list_models() if reachable else []

    vm = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    # No interval: returns the value sampled since the last call. The lifespan
    # primes it once so the first /health/detailed already has a real value.
    cpu_percent = psutil.cpu_percent(interval=None)

    return DetailedHealthResponse(
        status="ok" if reachable else "degraded",
        ollama_reachable=reachable,
        model=ollama.model,
        available_models=models,
        ram_used_mb=(vm.total - vm.available) // (1024 * 1024),
        ram_total_mb=vm.total // (1024 * 1024),
        cpu_percent=round(cpu_percent, 1),
        disk_used_gb=round(disk.used / (1024**3), 1),
        disk_total_gb=round(disk.total / (1024**3), 1),
    )
