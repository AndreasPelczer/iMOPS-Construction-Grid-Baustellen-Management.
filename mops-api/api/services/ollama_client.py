"""Async wrapper around the Ollama Python client."""

from __future__ import annotations

from ollama import AsyncClient
from loguru import logger


class OllamaClient:
    """Thin async wrapper around `ollama.AsyncClient`.

    The wrapper centralizes timeout, error logging and model selection so the
    rest of the codebase does not import the raw client.
    """

    def __init__(self, host: str, model: str, timeout: int) -> None:
        self._client = AsyncClient(host=host, timeout=timeout)
        self.model = model

    async def health_check(self) -> bool:
        """Return True if the Ollama server responds to `list()`."""
        try:
            await self._client.list()
            return True
        except Exception as exc:  # noqa: BLE001 — any exception means "not reachable"
            logger.warning(f"Ollama health check failed: {exc}")
            return False

    async def list_models(self) -> list[str]:
        """Return the list of model names currently installed in Ollama."""
        resp = await self._client.list()
        return [getattr(m, "model", "") for m in getattr(resp, "models", [])]

    async def chat(self, question: str, max_tokens: int = 500) -> tuple[str, int]:
        """Send a single user message to the configured model.

        Args:
            question: Natural-language question (any language Phi-3 handles).
            max_tokens: Upper bound for generated tokens (`num_predict`).

        Returns:
            Tuple of `(answer_text, generated_tokens)`. `generated_tokens` is 0
            if Ollama did not report it.
        """
        resp = await self._client.chat(
            model=self.model,
            messages=[{"role": "user", "content": question}],
            options={"num_predict": max_tokens},
        )
        # ollama-python returns a ChatResponse pydantic model in recent versions.
        message = getattr(resp, "message", None)
        text = getattr(message, "content", "") if message else ""
        eval_count = getattr(resp, "eval_count", 0) or 0
        return text, int(eval_count)
