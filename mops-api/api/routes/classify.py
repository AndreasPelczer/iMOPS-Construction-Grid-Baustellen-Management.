"""File classification endpoint — uses llama3.2:3b for intelligent file categorization."""

from __future__ import annotations

import json
import time

from fastapi import APIRouter, HTTPException, Request
from loguru import logger

from api.models import ClassifyRequest, ClassifyResponse
from api.services.ollama_client import OllamaClient

router = APIRouter(prefix="/classify", tags=["classify"])

VALID_CATEGORIES = [
    "GAEB-LV",
    "PDF-Dokument",
    "CAD-Plan",
    "Foto",
    "Excel-Mengen",
    "Unbekannt",
]

CLASSIFY_PROMPT = """Du bist ein File-Klassifikator fuer eine Baustellen-Management-App (iMOPS).

Klassifiziere die Datei in GENAU EINE der folgenden Kategorien:
- GAEB-LV (Leistungsverzeichnis: .x83, .x84, .x86, oder XML mit GAEB-Inhalt)
- PDF-Dokument (Plaene, Aufmass, Statik, Berichte)
- CAD-Plan (3D-Modelle: .skp, .obj, .usdz, .dae, .fbx, .stl, .gltf, .glb)
- Foto (Baustellenfotos: .jpg, .png, .heic)
- Excel-Mengen (Mengenermittlung, Kalkulation: .xlsx, .xls, .csv)
- Unbekannt (nichts davon)

Datei-Info:
- Filename: {filename}
- Endung: {extension}
- Groesse: {size_bytes} Bytes

Antworte NUR mit einem JSON-Objekt, KEIN anderer Text:
{{"category": "...", "confidence": 0.0-1.0, "reasoning": "kurze Begruendung"}}"""


def _ollama(request: Request) -> OllamaClient:
    return request.app.state.ollama


def _parse_classification(text: str) -> ClassifyResponse:
    """Parse the LLM JSON response, with fallback for malformed output."""
    cleaned = text.strip()
    # Strip markdown code fences if present
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        lines = [l for l in lines if not l.strip().startswith("```")]
        cleaned = "\n".join(lines).strip()

    try:
        data = json.loads(cleaned)
        category = data.get("category", "Unbekannt")
        if category not in VALID_CATEGORIES:
            category = "Unbekannt"
        return ClassifyResponse(
            category=category,
            confidence=max(0.0, min(1.0, float(data.get("confidence", 0.5)))),
            reasoning=data.get("reasoning"),
        )
    except (json.JSONDecodeError, TypeError, ValueError):
        logger.warning(f"Could not parse LLM classification: {text[:200]}")
        return ClassifyResponse(
            category="Unbekannt",
            confidence=0.0,
            reasoning="KI-Antwort nicht parsebar",
        )


@router.post("", response_model=ClassifyResponse)
async def classify_file(body: ClassifyRequest, request: Request) -> ClassifyResponse:
    """Classify a file using the local LLM based on filename, extension, and size."""
    ollama = _ollama(request)
    prompt = CLASSIFY_PROMPT.format(
        filename=body.filename,
        extension=body.extension,
        size_bytes=body.size_bytes,
    )

    start = time.perf_counter()
    try:
        answer, tokens = await ollama.chat(prompt, max_tokens=150)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Ollama classify failed")
        raise HTTPException(
            status_code=502,
            detail=f"Ollama-Anfrage fehlgeschlagen: {exc}",
        ) from exc

    duration_ms = int((time.perf_counter() - start) * 1000)
    logger.info(f"classify: {body.filename} -> {tokens} tokens in {duration_ms} ms")

    return _parse_classification(answer)
