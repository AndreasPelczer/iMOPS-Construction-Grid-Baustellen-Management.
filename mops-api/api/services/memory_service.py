"""Memory service — stores and manages Prof-Echos in Qdrant + Markdown.

Phase 1: Prof-Antworten werden als Qdrant-Points in prof_pending_v1 gespeichert
         und als Markdown mit YAML-Frontmatter in data/prof_echoes/pending/ abgelegt.
Phase 2: Admin-Freigabe verschiebt Echos von pending nach approved (Qdrant + Markdown).
"""

from __future__ import annotations

import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path

from loguru import logger
from qdrant_client import AsyncQdrantClient
from qdrant_client.models import (
    Distance,
    PointStruct,
    VectorParams,
)


# Qdrant collection names
PENDING_COLLECTION = "prof_pending_v1"
APPROVED_COLLECTION = "prof_echo_v1"

# Embedding dimension (all-MiniLM-L6-v2 = 384)
VECTOR_DIM = 384

# Markdown base directory
ECHO_BASE_DIR = Path(__file__).resolve().parent.parent / "data" / "prof_echoes"
PENDING_DIR = ECHO_BASE_DIR / "pending"
APPROVED_DIR = ECHO_BASE_DIR / "approved"


class MemoryService:
    """Verwaltet Prof-Echos in Qdrant und als Markdown-Dateien."""

    def __init__(self, qdrant_url: str = "http://localhost:6333") -> None:
        self._client = AsyncQdrantClient(url=qdrant_url)

    async def init_collections(self) -> None:
        """Stellt sicher, dass beide Collections existieren."""
        for name in (PENDING_COLLECTION, APPROVED_COLLECTION):
            if not await self._client.collection_exists(name):
                await self._client.create_collection(
                    collection_name=name,
                    vectors_config=VectorParams(
                        size=VECTOR_DIM,
                        distance=Distance.COSINE,
                    ),
                )
                logger.info(f"Qdrant-Collection '{name}' angelegt.")
            else:
                logger.debug(f"Qdrant-Collection '{name}' existiert bereits.")

        # Markdown-Verzeichnisse anlegen
        PENDING_DIR.mkdir(parents=True, exist_ok=True)
        APPROVED_DIR.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # Phase 1 — Echo speichern (aufgerufen vom Chat-Endpoint bei /prof)
    # ------------------------------------------------------------------

    async def store_pending(
        self,
        *,
        question: str,
        answer: str,
        vector: list[float],
        model: str,
        sources: list[dict],
        tokens_in: int,
        tokens_out: int,
        duration_ms: int,
    ) -> str:
        """Speichert eine Prof-Antwort als Pending-Echo (Qdrant + Markdown).

        Returns:
            Die generierte UUID des Echos.
        """
        entry_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        md_filename = f"{entry_id}.md"

        payload = {
            "question": question,
            "answer": answer,
            "model": model,
            "sources": sources,
            "tokens_in": tokens_in,
            "tokens_out": tokens_out,
            "duration_ms": duration_ms,
            "created_at": now,
            "status": "pending",
            "version": 1,
            "markdown_filename": md_filename,
        }

        # Qdrant upsert
        await self._client.upsert(
            collection_name=PENDING_COLLECTION,
            points=[
                PointStruct(
                    id=entry_id,
                    vector=vector,
                    payload=payload,
                ),
            ],
        )

        # Markdown schreiben
        self._write_markdown(PENDING_DIR / md_filename, payload)
        logger.info(f"Prof-Echo gespeichert: {entry_id}")
        return entry_id

    # ------------------------------------------------------------------
    # Phase 2 — Admin-Methoden
    # ------------------------------------------------------------------

    async def list_pending(self, limit: int = 50) -> list[dict]:
        """Listet alle Pending-Echos, neueste zuerst."""
        result = await self._client.scroll(
            collection_name=PENDING_COLLECTION,
            limit=limit,
            with_payload=True,
            with_vectors=False,
        )

        points = result[0] if result else []

        entries = []
        for point in points:
            p = point.payload or {}
            entries.append({
                "id": str(point.id),
                "question": p.get("question", ""),
                "answer": p.get("answer", ""),
                "sources": p.get("sources", []),
                "created_at": p.get("created_at", ""),
                "model": p.get("model", ""),
                "tokens_in": p.get("tokens_in", 0),
                "tokens_out": p.get("tokens_out", 0),
            })

        # Neueste zuerst
        entries.sort(key=lambda e: e["created_at"], reverse=True)
        return entries

    async def approve(self, entry_id: str) -> dict:
        """Freigabe-Workflow: pending → approved (Qdrant + Markdown)."""
        # 1. Point aus pending holen
        points = await self._client.retrieve(
            collection_name=PENDING_COLLECTION,
            ids=[entry_id],
            with_payload=True,
            with_vectors=True,
        )

        if not points:
            from fastapi import HTTPException

            raise HTTPException(
                status_code=404,
                detail=f"Echo '{entry_id}' nicht in pending gefunden.",
            )

        point = points[0]
        payload = dict(point.payload or {})
        now = datetime.now(timezone.utc).isoformat()

        # 2. Status aktualisieren und in approved-Collection schreiben
        payload["status"] = "approved"
        payload["approved_at"] = now

        await self._client.upsert(
            collection_name=APPROVED_COLLECTION,
            points=[
                PointStruct(
                    id=entry_id,
                    vector=point.vector,
                    payload=payload,
                ),
            ],
        )

        # 3. Aus pending loeschen
        await self._client.delete(
            collection_name=PENDING_COLLECTION,
            points_selector=[entry_id],
        )

        # 4. Markdown verschieben (wenn Filename im Payload steht)
        markdown_moved = False
        md_filename = payload.get("markdown_filename")
        new_path = ""

        if md_filename:
            src = PENDING_DIR / md_filename
            dst = APPROVED_DIR / md_filename
            if src.exists():
                shutil.move(str(src), str(dst))
                # 5. YAML-Frontmatter aktualisieren
                self._update_markdown_status(dst, now)
                new_path = str(dst)
                markdown_moved = True
                logger.info(f"Markdown verschoben: {src} → {dst}")
            else:
                logger.warning(f"Markdown nicht gefunden: {src}")
        else:
            logger.warning(f"Kein markdown_filename im Payload fuer {entry_id}")

        logger.info(f"Echo freigegeben: {entry_id}")

        return {
            "id": entry_id,
            "approved_at": now,
            "markdown_path": new_path,
            "markdown_moved": markdown_moved,
        }

    # ------------------------------------------------------------------
    # Markdown-Hilfsmethoden
    # ------------------------------------------------------------------

    @staticmethod
    def _write_markdown(path: Path, payload: dict) -> None:
        """Schreibt ein Echo als Markdown mit YAML-Frontmatter."""
        sources_yaml = ""
        for s in payload.get("sources", []):
            sources_yaml += f'  - lemma_id: "{s.get("lemma_id", "")}"\n'
            sources_yaml += f'    titel: "{s.get("titel", "")}"\n'
            sources_yaml += f'    score: {s.get("score", 0)}\n'

        content = f"""---
id: "{payload.get('id', payload.get('markdown_filename', '').replace('.md', ''))}"
status: {payload.get('status', 'pending')}
created_at: "{payload.get('created_at', '')}"
model: "{payload.get('model', '')}"
tokens_in: {payload.get('tokens_in', 0)}
tokens_out: {payload.get('tokens_out', 0)}
version: {payload.get('version', 1)}
original_sources:
{sources_yaml}---

## Frage

{payload.get('question', '')}

## Antwort

{payload.get('answer', '')}
"""
        path.write_text(content, encoding="utf-8")

    @staticmethod
    def _update_markdown_status(path: Path, approved_at: str) -> None:
        """Aktualisiert status und approved_at im YAML-Frontmatter."""
        text = path.read_text(encoding="utf-8")
        text = text.replace("status: pending", f"status: approved\napproved_at: \"{approved_at}\"", 1)
        path.write_text(text, encoding="utf-8")
