# Spec — OCR/Vision-Fallback für kaputte Text-Layer (C1Pdf & Co.)

> Design-Spec, Stand 2026-07-05. Umsetzungsreif, noch nicht gebaut.
> Ergänzt `docs/Stufe2-Dokumenten-Extraktion.md`. Ziel-Repo: **mops-api** (Box),
> nicht der iOS-Client. Selbsttragend — der Bauende (Codi/Codex) sieht die
> auslösende Unterhaltung NICHT.
>
> **⚠️ Nachtrag 2026-07-07 (Code-Abgleich gegen die laufende Box):** Zwei Annahmen
> des Entwurfs stimmen mit dem echten mops-api-Code nicht überein — korrigiert unten
> und gebündelt in **§7 „Code-Abgleich"**. Kurz: (1) die Box nutzt **PyMuPDF (fitz)**,
> nicht `pdftotext`/`pdftoppm` (Poppler ist auf der Box gar nicht installiert);
> (2) die LLM-Clients können **heute nur Text** — eine Bild/Vision-Methode existiert
> nicht und ist der **erste zu bauende Baustein**. Konkreter Umsetzungsauftrag:
> `docs/CODEX-AUFTRAG-Vision-Fallback-C1Pdf.md`.

## 1. Problem (real belegt am 2026-07-05)

Aus dem Büro kommen **Town-&-Country-Leistungsverzeichnisse** als PDF. Diese sind
**digital (haben eine Textebene), aber die Textextraktion liefert Müll** — der Mops
(`/extract-doc` / `/extract-plan`) scheitert daran.

Belegdatei: `aura125-lv-1.PDF` (80 S., "Aura 125", LV 0207).
- `/Producer (ComponentOne C1Pdf)` — die Export-Engine von T&C.
- 8 Type0/CID-Fonts, aber nur **4 ToUnicode-Maps** → die Glyphen sind gezeichnet,
  aber die Zeichen→Unicode-Zuordnung fehlt zur Hälfte.
- Folge: `pdftotext` liefert leere/kaputte Zeichen. Vision/OCR liest die Seiten
  dagegen einwandfrei (heute manuell verifiziert).

**Die bestehende Stufe-2-Heuristik greift hier NICHT:** sie erkennt nur
„< 200 Zeichen/Seite → Zeichnung (Stufe 3)". Hier ist Text DA, nur unbrauchbar.

## 2. Zwei Ergänzungen

### 2a. Bessere Erkennung „Text ist Müll" (nicht nur „Text ist wenig")

Pro Seite auf dem fitz-Rohtext (`page.get_text("text")` — **nicht** `pdftotext`, s. §7)
prüfen; als **unbrauchbar** werten wenn:
- (a) < ~200 verwertbare Zeichen/Seite (bestehende Regel), ODER
- (b) **Klartext-Anteil zu niedrig**: Anteil der Zeichen in `[A-Za-zÄÖÜäöüß0-9 .,;:()\-/]`
  unter ~0,6, oder Anteil „echter Wörter" (≥3 Buchstaben, mit Vokal) zu klein.
- **Producer-Signal (harter Shortcut):** `doc.metadata.get("producer")` enthält
  „C1Pdf" / „ComponentOne" → Dokument direkt als „Text unbrauchbar → Vision" markieren,
  ohne Zeichen-Heuristik. (fitz liefert den Producer aus den PDF-Metadaten.)

Wichtig: Unterscheiden von „echter Zeichnung/Plan" (Stufe 3). Merkmal: eine C1Pdf-LV
hat viele Fonts + wenig/keine großen Bild-XObjects; ein gescannter Plan ist umgekehrt.
Im Zweifel: Vision-Fallback ist für beide Fälle die richtige Rettung.

### 2b. Vision-Fallback statt 422

Wenn die Text-Pipeline versagt:
1. Seiten rendern **mit fitz** (kein `pdftoppm`): `page.get_pixmap(dpi=150).tobytes("png")`
   → eine PNG je Seite, direkt im Speicher.
2. Seiten **in Blöcken parallel** an ein Vision-fähiges Modell schicken, mit demselben
   Ziel-JSON-Schema wie die Text-Pipeline. **⚠️ Blocker (s. §7):** die heutigen Clients
   (`ClaudeClient`/`OpenAIClient`) haben **nur `complete_json(prompt)` — text-only**.
   Eine bild-fähige Methode (`complete_json_vision(images, prompt)`, base64-PNG +
   `media_type`) muss **zuerst** ergänzt werden. Claude- wie gpt-4.1-Modelle sind
   vision-fähig; es fehlt nur der Client-Weg.
3. Ergebnisse mergen, Positions-Nummern auf Lückenlosigkeit prüfen, JSON zurückgeben.

> Genau dieses Muster wurde am 2026-07-05 manuell gefahren: 4 parallele Leser über
> die 80 Seiten → **241 LV-Positionen, lückenlos**, in < 2 Min. Der Fallback ist also
> erprobt, er muss nur in die Route.

**Ziel-Schema für LVs** = das bestehende `ExtractPlanResult` (siehe
`Models/ExtractPlanResult.swift`): `{ metadata, lv_positionen[], bestellliste[], etiketten }`
mit `lv_positionen[] = {posNr, bezeichnung, kg, einheit, menge, quelle}`. **JSON-Schlüssel
beachten:** Top-Level `lv_positionen` (snake), innere Felder **camelCase** (`posNr`,
`bezeichnung`, `einheit`, `menge`, `kg`, `quelle`) — der iOS-Decoder ist ein nacktes
`JSONDecoder()` ohne snake-case-Strategie.

## 3. Kosten & Betrieb

- Vision ist teurer als Text (Token je Seite-Bild) → **nur Fallback**, nie Default.
  Explizit ausgelöst (Button „Unterlagen auswerten"), nicht bei jedem Upload.
- Seiten-Blöcke parallel (wie die 4 Leser), damit ein 80-Seiten-LV zügig durchläuft.
- Deploy wie Geländebrücke-Runbook (uvicorn manuell, `setsid` + SSH ~8 s offen halten;
  siehe `docs/HANDOFF-2026-07-04.md` §WP3 falls vorhanden, sonst Box-Runbook).

## 4. Fixture / Regressionstest (liegt bereit)

| Fixture | Soll |
|---|---|
| `aura125-lv-1.PDF` (C1Pdf, kaputter Text-Layer) | **241 LV-Positionen, lückenlos**; Titel 00–22 (12 leer); Estrich unter 14.02; Mengen deutsch-dezimal korrekt |
| Erwartungs-JSON | `~/Desktop/mopsss/LV/aura125-lv.json` (heute manuell erzeugt, 1:1 als Soll) |

Stichproben: `00.01.01 Toilette 1 psch` · `01.01.01 Oberboden abtragen 35,153 m³`
· `03.01.02 Bodenplattenbeton 78 m²` · `14.02.28 PEDOTHERM Heizestrich 60,883 m²`
· `15.02.29 …Türklingel… T&C 1 St`.

## 5. Client (iOS) — Anschluss

- **Kein neuer Weg nötig für den Normalfall:** liefert der Mops die JSON, greift der
  bestehende `ExtractPlanMapper` + LV-Import-Review (Human-in-the-Loop bleibt Pflicht).
- **Offene Kleinigkeit:** Für die HEUTE schon manuell erzeugte `aura125-lv.json` fehlt
  ein **Datei-Import-Pfad** in der App (die App zieht ExtractPlanResult sonst nur live
  vom Endpoint). Optionaler kleiner Dev-Hook „LV aus JSON-Datei importieren" wäre
  nützlich, um solche extern erzeugten JSONs einzuspielen — eigenständig, nicht
  Teil des Backend-Fixes.

## 6. Explizit NICHT in Scope

- Kein Ersatz der Text-Pipeline — Vision bleibt Fallback.
- Keine automatische Vision-Auslösung ohne Nutzer-Klick (Kosten).
- Kein neues LLM-Konto — vorhandenes Claude/OpenAI-Setup wiederverwenden.

## 7. Code-Abgleich mit der laufenden Box (Stand 2026-07-07)

Gegen den echten `mops-api`-Code auf der Box geprüft. Die Ankerpunkte für die Umsetzung:

**Zwei Wege, zwei Einhängepunkte:**
| Route | Datei | Art | Für |
|---|---|---|---|
| `/extract-plan` | `api/routes/extract.py` → `api/services/extract/__init__.py::extract_all` | **regelbasiert** (Regex-Parser `waende/bauteile/bewehrung/lv`), kein LLM | **LVs → `ExtractPlanResult`** — der T&C-Weg, primäres Ziel |
| `/extract-doc` | `api/routes/extract_doc.py` → `api/services/doc_extract.py::extract_doc` | LLM (`llm.complete_json`) | Bodengutachten etc., generische Felder |

**Was heute existiert / fehlt:**
- Text kommt aus **fitz** `get_text("text")` (`doc_extract.py::pdf_zu_text`, `extract_all`). **Kein `pdftotext`/`pdftoppm` auf der Box.**
- Einzige „unlesbar"-Bremse: **Zeichen-*Anzahl*** `MIN_CHARS_PER_PAGE = 200` (`doc_extract.py:23`, Guard bei `:172` → `ZuWenigText` → HTTP 422). **Greift bei C1Pdf NICHT** (viel Text, nur Müll). `/extract-plan` hat gar keine Bremse — der Regel-Parser liefert bei Müll-Text still leere/falsche Positionen.
- **Vorgemerkt, aber ohne Weg dahinter:** `extract/__init__.py:45` zählt bereits `"seiten_vision_noetig"` in die Metadaten.
- **Vision-Blocker:** `claude_client.py:126` und `openai_client.py:119` bieten nur `complete_json(prompt)` — **text-only, keine Bild-Methode**. Das ist das erste zu bauende Stück.

**Reihenfolge der Umsetzung** → ausführlich als Auftrag in
`docs/CODEX-AUFTRAG-Vision-Fallback-C1Pdf.md`:
1. Bild-Methode in beide Clients (`complete_json_vision`).
2. PDF-Helfer: Producer-Check (`doc.metadata`), Müll-Text-Erkennung, `get_pixmap`-Render.
3. Vision-Fallback-Funktion (render → Blöcke → Vision → merge → Lückencheck → `ExtractPlanResult`).
4. Einhängen in `/extract-plan` (primär) und `/extract-doc` (analog), **nur auf Nutzer-Klick**.
5. Regressionstest gegen die 241er-Fixture.
