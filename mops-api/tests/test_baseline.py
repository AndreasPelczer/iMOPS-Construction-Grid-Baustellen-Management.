"""Baseline-Test ohne RAG.

Schickt jede Frage aus `data/tests/baseline_questions.json` an `/chat` und
schreibt die Antworten in `data/tests/baseline_results_<timestamp>.json`,
damit Andreas und Raffi sie spaeter manuell bewerten koennen.

Per Default laeuft jeder Test bis zu 5 Minuten — Phi-3 auf CPU ist langsam.

Konfiguration ueber Umgebungsvariablen:
    MOPS_BASE_URL     (Default: http://localhost:8080)
    MOPS_MAX_TOKENS   (Default: 500)
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx
import pytest

ROOT = Path(__file__).resolve().parent.parent
QUESTIONS_FILE = ROOT / "data" / "tests" / "baseline_questions.json"
RESULTS_DIR = ROOT / "data" / "tests"

BASE_URL = os.environ.get("MOPS_BASE_URL", "http://localhost:8080")
MAX_TOKENS = int(os.environ.get("MOPS_MAX_TOKENS", "500"))
REQUEST_TIMEOUT_S = 300.0


def _load_questions() -> list[tuple[str, str]]:
    """Return [(category, question), ...]; empty if the JSON is missing."""
    if not QUESTIONS_FILE.exists():
        return []
    data = json.loads(QUESTIONS_FILE.read_text(encoding="utf-8"))
    items: list[tuple[str, str]] = []
    items.extend(("real", q) for q in data.get("real_questions", []))
    items.extend(("trap", q) for q in data.get("trap_questions", []))
    return items


_results: list[dict] = []


@pytest.fixture(scope="session", autouse=True)
def _save_results_at_end():
    """Persist all collected answers when the test session ends."""
    yield
    if not _results:
        return
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    out = RESULTS_DIR / f"baseline_results_{timestamp}.json"
    out.write_text(
        json.dumps(
            {
                "base_url": BASE_URL,
                "max_tokens": MAX_TOKENS,
                "results": _results,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"\nBaseline-Ergebnisse gespeichert: {out}")


def _short_id(category: str, question: str) -> str:
    snippet = question[:50] + ("..." if len(question) > 50 else "")
    return f"{category}:{snippet}"


@pytest.mark.parametrize(
    ("category", "question"),
    _load_questions(),
    ids=lambda v: v if isinstance(v, str) else "",
)
def test_baseline_question(category: str, question: str) -> None:
    """Schicke eine Frage an /chat und sammle die Antwort fuer manuelle Review."""
    start = time.perf_counter()
    with httpx.Client(base_url=BASE_URL, timeout=REQUEST_TIMEOUT_S) as client:
        resp = client.post(
            "/chat",
            json={"question": question, "max_tokens": MAX_TOKENS},
        )
    duration_ms = int((time.perf_counter() - start) * 1000)

    assert resp.status_code == 200, f"HTTP {resp.status_code}: {resp.text[:200]}"
    payload = resp.json()
    answer = payload.get("answer", "")

    _results.append(
        {
            "id": _short_id(category, question),
            "category": category,
            "question": question,
            "answer": answer,
            "tokens": payload.get("tokens"),
            "model": payload.get("model"),
            "duration_ms": duration_ms,
            "asked_at": datetime.now(timezone.utc).isoformat(),
            # Manuell nach dem Lauf ausfuellen:
            "rating": None,  # "correct" | "partial" | "wrong" | "hallucination" | "refused"
            "reviewer_note": "",
        }
    )

    assert answer.strip(), "Leere Antwort vom Modell"
