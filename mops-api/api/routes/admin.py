"""Admin endpoints — Freigabe-Workflow fuer Prof-Echos."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

router = APIRouter(prefix="/admin", tags=["admin"])


class PendingEntry(BaseModel):
    """Ein einzelner Pending-Echo-Eintrag."""

    id: str
    question: str
    answer: str
    sources: list[dict]
    created_at: str
    model: str
    tokens_in: int
    tokens_out: int


class ApproveResponse(BaseModel):
    """Antwort nach erfolgreicher Freigabe."""

    id: str
    approved_at: str
    markdown_path: str
    markdown_moved: bool


@router.get("/pending", response_model=list[PendingEntry])
async def list_pending(request: Request, limit: int = 50) -> list[PendingEntry]:
    """Listet alle Pending-Echos, neueste zuerst."""
    memory = request.app.state.memory_service
    entries = await memory.list_pending(limit=limit)
    return [PendingEntry(**e) for e in entries]


@router.post("/approve/{entry_id}", response_model=ApproveResponse)
async def approve_entry(entry_id: str, request: Request) -> ApproveResponse:
    """Gibt einen Pending-Echo frei (pending → approved)."""
    memory = request.app.state.memory_service
    result = await memory.approve(entry_id)
    return ApproveResponse(**result)
