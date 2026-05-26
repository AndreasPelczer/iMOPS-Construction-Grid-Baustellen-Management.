"""Pydantic request/response schemas for the Mops-API."""

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Minimal health probe response."""

    status: str
    ollama_reachable: bool
    model: str


class DetailedHealthResponse(BaseModel):
    """Extended health probe with system metrics."""

    status: str
    ollama_reachable: bool
    model: str
    available_models: list[str]
    ram_used_mb: int
    ram_total_mb: int
    cpu_percent: float
    disk_used_gb: float
    disk_total_gb: float


class ChatRequest(BaseModel):
    """Single-shot question for Phi-3 (no RAG in baseline)."""

    question: str = Field(min_length=1, max_length=4000)
    max_tokens: int = Field(default=500, ge=1, le=4000)


class ChatResponse(BaseModel):
    """Phi-3 answer plus telemetry."""

    answer: str
    model: str
    duration_ms: int
    tokens: int


class ClassifyRequest(BaseModel):
    """File classification request from iMOPS FileInspector."""

    filename: str
    extension: str
    size_bytes: int = 0


class ClassifyResponse(BaseModel):
    """KI-Klassifikation einer Datei."""

    category: str
    confidence: float
    reasoning: str | None = None
