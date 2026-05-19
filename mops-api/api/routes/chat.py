"""Chat endpoint — baseline version without RAG."""

from __future__ import annotations

import time

from fastapi import APIRouter, HTTPException, Request
from loguru import logger

from api.models import ChatRequest, ChatResponse
from api.services.ollama_client import OllamaClient

router = APIRouter(prefix="/chat", tags=["chat"])


def _ollama(request: Request) -> OllamaClient:
    return request.app.state.ollama


@router.post("", response_model=ChatResponse)
async def chat(body: ChatRequest, request: Request) -> ChatResponse:
    """Forward a question directly to Phi-3 (no retrieval yet).

    This endpoint exists to establish a baseline: how good (or bad) is Phi-3
    on German construction questions WITHOUT a knowledge base? Once we have
    RAG, we will compare against these numbers.

    Args:
        body: Question and `max_tokens` budget.

    Returns:
        Answer text plus model name, wall-clock duration and token count.
    """
    ollama = _ollama(request)
    start = time.perf_counter()
    try:
        answer, tokens = await ollama.chat(body.question, max_tokens=body.max_tokens)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Ollama chat failed")
        raise HTTPException(
            status_code=502,
            detail=f"Ollama-Anfrage fehlgeschlagen: {exc}",
        ) from exc

    duration_ms = int((time.perf_counter() - start) * 1000)
    logger.info(f"chat: {tokens} tokens in {duration_ms} ms")

    return ChatResponse(
        answer=answer,
        model=ollama.model,
        duration_ms=duration_ms,
        tokens=tokens,
    )
