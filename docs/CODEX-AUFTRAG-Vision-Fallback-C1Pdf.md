# Codex-Auftrag — Vision-Fallback für C1Pdf-LVs (Town & Country)

> **Ziel-Repo: `mops-api` (die Box), NICHT der iOS-Client.** Dieser Auftrag ist
> selbsttragend — du siehst die auslösende Unterhaltung nicht. Alles Nötige steht hier.
> Design-Hintergrund: `docs/Stufe2-OCR-Vision-Fallback-Spec.md` (dort §7 = Code-Abgleich).
> **Fertig-Kriterium:** `aura125-lv-1.PDF` → **241 lückenlose LV-Positionen** über den
> neuen Vision-Weg, deckungsgleich mit der Soll-JSON (siehe §7 Regressionstest).

## 0. Das Problem in drei Sätzen

Town-&-Country-Leistungsverzeichnisse werden von **ComponentOne C1Pdf** erzeugt. Sie
haben eine Textebene, aber die ist **kaputt** (CID-Fonts ohne vollständige ToUnicode-Maps
→ `fitz.get_text` liefert Buchstabensalat). Der Mops braucht deshalb einen **Vision-Fallback**:
Seiten als Bild rendern und von einem vision-fähigen Modell lesen lassen. Manuell schon
erprobt (241 Positionen in < 2 Min).

## 1. Ankerpunkte im bestehenden Code (Stand 2026-07-07)

| Zweck | Datei | Merkmal |
|---|---|---|
| LV-Weg (**primär**) | `api/routes/extract.py` → `api/services/extract/__init__.py::extract_all` | regelbasiert, öffnet PDF 1× mit fitz, baut `ExtractPlanResult` |
| Doc-Weg | `api/routes/extract_doc.py` → `api/services/doc_extract.py::extract_doc` | LLM `complete_json`, Guard `MIN_CHARS_PER_PAGE=200` (`:23`/`:172`) |
| LLM-Client Claude | `api/services/claude_client.py:126` | nur `complete_json(prompt, max_tokens)` — **text-only** |
| LLM-Client OpenAI | `api/services/openai_client.py:119` | nur `complete_json(prompt, max_tokens)` — **text-only** |
| Provider-Wahl | `api/routes/extract_doc.py::_extract_llm` | Env `EXTRACT_PROVIDER` (`anthropic`|`openai`), Modelle aus `settings` |
| Vorgemerktes Feld | `api/services/extract/__init__.py:45` | zählt schon `"seiten_vision_noetig"` |

**Wichtig:** Auf der Box gibt es **kein Poppler** (`pdftotext`/`pdftoppm`). Alles über
**PyMuPDF (fitz)** — auch das Rendern (`page.get_pixmap`).

## 2. Aufgabe — in dieser Reihenfolge

### Schritt 1 — Bild-Methode in beide LLM-Clients (der Blocker zuerst)
In `claude_client.py` und `openai_client.py` je eine neue Methode **neben** `complete_json`
(die Text-Methode unangetastet lassen):

```python
async def complete_json_vision(
    self, images: list[bytes], prompt: str, max_tokens: int = 4000
) -> str:
    ...
```
- `images` = PNG-Bytes je Seite.
- **Claude** (`claude_client.py`): Messages-API, `content`-Array aus je einem
  `{"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": <b64>}}`
  pro Bild **plus** einem `{"type": "text", "text": prompt}`. Request-Aufbau/Auth/Timeout
  **1:1 wie im bestehenden `complete_json` spiegeln**, nur der Content ändert sich.
- **OpenAI** (`openai_client.py`): `content`-Array mit `{"type":"text",...}` und je Bild
  `{"type":"image_url","image_url":{"url":"data:image/png;base64,<b64>"}}`. gpt-4.1 ist vision-fähig.
- Rückgabe: der rohe Text der Antwort (wie `complete_json`) — das JSON-Parsen macht der Aufrufer.

### Schritt 2 — PDF-Helfer (neues Modul `api/services/pdf_vision.py`)
```python
import fitz

def producer(doc) -> str:                    # doc.metadata.get("producer") or ""
def ist_c1pdf(doc) -> bool:                  # "c1pdf" in producer.lower() or "componentone" in ...
def seite_text_muell(text: str) -> bool:     # §3-Heuristik (Klartext-Anteil < 0.6 ODER zu wenig echte Wörter)
def render_seiten_png(doc, dpi: int = 150) -> list[bytes]:
    return [p.get_pixmap(dpi=dpi).tobytes("png") for p in doc]
```

### Schritt 3 — Vision-Fallback-Funktion (in `pdf_vision.py`)
```python
async def extract_lv_via_vision(pdf_bytes, llm, block_size=15) -> dict:
    # 1. fitz.open → render_seiten_png
    # 2. Seiten in Blöcke à block_size, je Block parallel (asyncio.gather) an
    #    llm.complete_json_vision(bilder, PROMPT_LV) — PROMPT fordert exakt das
    #    ExtractPlanResult-Schema (siehe §4) als JSON, nur die Positionen des Blocks.
    # 3. json_aus_antwort (Helper aus doc_extract.py wiederverwenden), lv_positionen mergen,
    #    nach posNr sortieren, auf Lückenlosigkeit prüfen (Lücken loggen, nicht crashen).
    # 4. dict im ExtractPlanResult-Shape zurückgeben.
```
Blockgröße konfigurierbar; Default so, dass ein 80-Seiten-LV zügig durchläuft (Referenz:
4 parallele Leser am 5.7.).

### Schritt 4 — Einhängen (nur auf Nutzer-Klick)
- **`/extract-plan`** (primär): in `extract_all` bzw. der Route **vor** dem Regel-Parser
  prüfen: `ist_c1pdf(doc)` ODER Mehrheit der Seiten `seite_text_muell` → **Vision-Weg**
  statt Regel-Parser. Sonst wie bisher.
- **`/extract-doc`**: analog — statt `ZuWenigText`-422 bei brauchbarer-Menge-aber-Müll
  den Vision-Weg nehmen.
- **Auslösung:** neuer Query/Form-Parameter `allow_vision: bool = False` (bzw.
  Env/Flag). Vision **nur** wenn gesetzt (Kosten). Ohne Flag: heutiges Verhalten, aber
  im Fehlerfall Hinweis „Text unbrauchbar (C1Pdf) — mit Vision erneut senden".

### Schritt 5 — Regressionstest
Test in `tests/`, der `aura125-lv-1.PDF` durch den Vision-Weg schickt (LLM in der CI
mockbar) **oder** mindestens die Erkennung (`ist_c1pdf`, `seite_text_muell`) und den
Merge/Lückencheck deterministisch prüft. Soll: **241 Positionen, lückenlos.**

## 3. Erkennungs-Schwellen (aus der Spec)
Seite/Dokument als **Text unbrauchbar** werten wenn:
- `/Producer` enthält „C1Pdf"/„ComponentOne" (harter Shortcut, reicht allein), ODER
- Klartext-Anteil (Zeichen in `[A-Za-zÄÖÜäöüß0-9 .,;:()\-/]`) < ~0,6, ODER
- Anteil „echter Wörter" (≥3 Buchstaben, mit Vokal) zu klein.
Abgrenzen gegen **echte Zeichnung** (Stufe 3): C1Pdf-LV = viele Fonts + kaum große
Bild-XObjects; gescannter Plan = umgekehrt. Im Zweifel Vision (rettet beide Fälle).

## 4. Ziel-Schema (`ExtractPlanResult`) — Schlüssel genau beachten
`{ metadata, lv_positionen[], bestellliste[], etiketten }` mit
`lv_positionen[] = {posNr, bezeichnung, kg, einheit, menge, quelle}`.
**Top-Level `lv_positionen` snake_case, innere Felder camelCase** (`posNr`, `bezeichnung`,
`einheit`, `menge`, `kg`, `quelle`) — der iOS-Decoder ist ein nacktes `JSONDecoder()`
ohne snake-case-Strategie. Halte dich an das, was `extract_all` heute schon zurückgibt.

## 5. Akzeptanz / Fixture
| Fixture | Soll |
|---|---|
| `aura125-lv-1.PDF` (C1Pdf) | 241 LV-Positionen, lückenlos; Titel 00–22 (12 leer); Estrich unter 14.02; Mengen deutsch-dezimal |
| Stichproben | `01.01.01 Oberboden abtragen 35,153 m³` · `03.01.02 Bodenplattenbeton 78 m²` · `14.02.28 PEDOTHERM Heizestrich 60,883 m²` |

## 6. Stolpersteine (Stunden sparen)
- **Der 200-Zeichen-Guard rettet dich NICHT** bei C1Pdf (Text ist reichlich, nur Müll) — deshalb der Producer-/Müll-Check.
- **fitz statt Poppler** — nicht `pdftoppm`/`pdftotext` aufrufen (nicht installiert).
- **Deutsch-Dezimal** (`35,153`) korrekt übernehmen, nicht auf Punkt normalisieren, wenn das Schema Komma erwartet — am Soll prüfen.
- **Vision ist teuer** → strikt Fallback, nie Default, nur mit `allow_vision`.
- Provider kann `openai` (gpt-4.1) sein, wenn Claude-Guthaben leer — **beide** Clients müssen die Vision-Methode haben.

## 7. Deploy & Grenzen
- **Neustart macht Andreas:** `sudo systemctl restart mops-api` braucht sein Passwort
  (passwortloses sudo geht auf der Box nicht). Du baust + testest, den Restart triggert er.
- **Kein Ersatz der Text-Pipeline** — Vision bleibt Fallback.
- **DSGVO:** die echte `aura125-lv.json`/`.PDF` sind **Kundendaten** und liegen nur auf
  Andreas' Desktop. Kommt eine Fixture ins Repo, dann **anonymisiert** (Namen/Adressen raus).
- Branch/PR nach Repo-Konvention (`feature/…`, Conventional Commits). Nicht direkt auf `main`.
