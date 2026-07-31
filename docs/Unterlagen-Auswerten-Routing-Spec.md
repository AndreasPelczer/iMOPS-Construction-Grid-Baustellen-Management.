# Spec: Ein „Unterlagen auswerten" für den ganzen Projekt-Stapel · Stand 8.7.2026

**Status:** Diskussions-/Design-Grundlage. Noch nichts gebaut. Spannt **App + Box (mops-api)**.
**Verwandt:** `docs/Stufe2-Dokumenten-Extraktion.md`, `docs/Stufe2-OCR-Vision-Fallback-Spec.md`,
`docs/HANDOFF-Auswertung-speichern.md`, `docs/Baustellen-Uebersicht-Spec.md`.

---

## 1) Wunsch (Andreas)

Heute gibt es **zwei Knöpfe**, die beide PDFs einlesen:
- **„Unterlagen auswerten"** (Stufe 2, `/extract-doc`) → Dokument-Fakten (Bodengutachten,
  Wohnfläche, Bebauungsplan, Erschließung).
- **„PDF in LV importieren"** (`/extract-plan`) → LV-Positionen.

Lädt man den ganzen Projekt-Stapel zum Auswerten, sind LVs mit dabei — die muss man aktuell
**ein zweites Mal** über den LV-Import einlesen. Wunsch: **einmal einlesen**, die App erkennt
LVs im Stapel und speichert sie gleich (mit Prüfung). „Das sind doch dieselben Infoquellen."

---

## 2) Ist-Zustand im Code

### Zwei Extraktoren für zwei Dokument-Arten (das „anders gedacht")
| Datei-Art | Route | Technik | Ergebnis-Modell |
|---|---|---|---|
| **LV** | `/extract-plan` (`api/routes/extract.py` → `extract_all`) | **regel-basiert** (Regex-Parser), kein LLM, billig | `ExtractPlanResult` |
| **Text-Dok** | `/extract-doc` (`api/routes/extract_doc.py` → `extract_doc`) | **LLM** (`/prof` → Claude/OpenAI), kostet Tokens | `ExtractDocResult` |

Beides auf jede Datei loszulassen ist falsch: LV→extract-doc = Fakten-Kauderwelsch,
Gutachten→extract-plan = null Positionen, plus doppelte (LLM-)Kosten.

### Klassifizierung nur nach Datei-*Typ*, nicht Inhalt
`Models/FileClassification.swift` (`FileCategory`: gaebLV/pdfDocument/cadPlan/photo/…) kennt nur
die **Datei-Art** (ein PDF ist „pdfDocument") — **nicht** „ist dieses PDF ein LV oder ein
Gutachten?". Genau diese **inhaltliche** Erkennung fehlt. Es gibt heute keine „lv"-Doctype-Erkennung.

### Einstiegspunkte (iOS)
- `EventDetailView`: Button „Unterlagen auswerten" (~Z.1056) → `starteUnterlagenAuswertung`
  (~Z.1142, ruft `MopsClient.extractDoc`) → `UnterlageAuswertungView` (Sheet ~Z.477).
- LV-Import: `LVImportView` → `parsePDFsViaMops` (`MopsClient.extractPlan`) →
  `ExtractPlanMapper.toParsed` → Review-Liste `parsedPositions` → `importSelected()` schreibt `LVPosition`s.
- Beide nutzen den Multi-Picker `PDFDocumentPicker`.
- Dokument-Fakten werden seit 7.7. in `EventExtrasPayload.auswertungen` persistiert
  (`GespeicherteAuswertung`, siehe `HANDOFF-Auswertung-speichern.md`).

---

## 3) Zielbild: ein Knopf, der sortiert

**„Unterlagen auswerten" wird DER Einstieg für den ganzen Stapel:**
1. Alle PDFs auf einmal wählen (ein Picker — `PDFDocumentPicker` wiederverwenden).
2. **Pro Datei auf der Box klassifizieren:** LV oder Dokument.
3. **Routen (genau EIN Extraktor pro Datei):**
   - **LV** → `/extract-plan` → in die **LV-Review** (Mensch hakt ab → `LVPosition`s).
   - **Dokument** → `/extract-doc` → Fakten → **gleich gespeichert** (extras.auswertungen).
4. **Ein kombiniertes Ergebnis:** „3 LVs erkannt → Positionen prüfen · 5 Dokumente
   ausgewertet → Fakten gespeichert · 1 übersprungen (Zeichnung)."

**Bewusste Ausnahme vom „gleich speichern":** LV-Positionen werden **echte Geld-Positionen**
→ bleiben **Human-in-the-Loop** (Review vor dem Speichern). Dokument-*Fakten* sind leichter
(Notizen) → dürfen direkt rein (mit Auswahl wie in `HANDOFF-Auswertung-speichern.md`).

---

## 4) Box-Änderung (mops-api) — die Klassifizierung

**Entscheidung (Andreas): auf der Box, „try-extract-plan-first".** Der Regel-Parser ist billig
und ein guter LV-Detektor.

**Neuer Endpoint `POST /extract-auto`** (multipart: `doc_file` + optional `projekt`/`baustelle`):
```
1. Text via fitz ziehen (wie bisher).
2. extract_all() laufen lassen (regel-basiert, billig).
3. Zählen: plausible LV-Positionen (posNr + menge + einheit).
   - >= SCHWELLE (z. B. 3)  → kind="lv",  payload = ExtractPlanResult
   - sonst                  → extract_doc() (LLM) → kind="doc", payload = ExtractDocResult
4. Liefert Discriminated Union:  { "kind": "lv"|"doc"|"skip", ...payload..., "quelle": <name> }
   - "skip": weder LV noch verwertbarer Text (Zeichnung / kaputter Text-Layer) → Hinweis.
```
- **Kostenvorteil:** LLM (`extract_doc`) läuft NUR auf Nicht-LVs. LVs sind gratis (regel-basiert).
- **Schwelle** konfigurierbar; im Zweifel (1–2 Treffer) → als „doc" behandeln und im Ergebnis
  markieren („evtl. LV — bitte prüfen").
- **C1Pdf-Kopplung:** Der Regel-Parser braucht lesbaren Text. Bei kaputtem Text-Layer (Town &
  Country / „ComponentOne C1Pdf", siehe `Stufe2-OCR-Vision-Fallback-Spec.md`) findet er nichts
  → würde fälschlich „doc"/„skip". **Der Vision-Fallback ist also die Voraussetzung**, damit
  solche LVs überhaupt als LV erkannt werden. Bis der steht: C1Pdf-LVs bleiben der bekannte
  Sonderweg (manuelles JSON / `/extract-plan` mit Vision).

Alternativ (falls `/extract-auto` zu groß): erst ein leichtes `POST /classify-pdf` → `{kind}`,
dann ruft die App den passenden bestehenden Endpoint. **Empfehlung: `/extract-auto`** (ein
Round-Trip/Datei, Box entscheidet, App bleibt dumm).

---

## 4b) PRÄZISIERUNG: Klassifizierung übers vorhandene Vision-Gate (verifiziert 8.7.2026)

**Kernbefund (Code geprüft):** Der Vision-Fallback ist **schon in `/extract-plan` eingehängt**
(`api/routes/extract.py:87–116`) — nicht „später". Ablauf dort:

```
PDF öffnen → pdf_vision.braucht_vision(doc, pages_text)?
 ├─ True (Text-Layer kaputt, C1Pdf/T&C):
 │     allow_vision=false → HTTP 422 "Text unbrauchbar … erneut mit allow_vision=true"
 │     allow_vision=true  → pdf_vision.extract_lv_via_vision(...) → LV-Positionen (LLM/Bild)
 └─ False (sauberer Text) → extract_all(...) (Regel-Parser, gratis)
```
Detektoren liegen in `api/services/pdf_vision.py` (`braucht_vision`, `seite_text_muell`,
`producer`, `ist_c1pdf`). Der **Kosten-Schutz** ist der `allow_vision`-Opt-in: Vision feuert
**nie heimlich**, der Client bestätigt pro Datei.

**Konsequenz für `/extract-auto` — NICHT nacktes `extract_all` zum Klassifizieren, sondern
dasselbe `braucht_vision`-Gate wiederverwenden.** Das nackte `extract_all` würde bei C1Pdf
(kaputter Text) 0 Positionen finden → fälschlich `doc` → an `extract_doc` (LLM) → **Müll wird
gespeichert + Tokens verbrannt** (die eigentliche Falle des Konzepts). Stattdessen:

```
POST /extract-auto (pro Datei):
 1. fitz öffnen, pages_text, braucht_vision = pdf_vision.braucht_vision(doc, pages_text)
 2. braucht_vision == True  (C1Pdf/T&C, Bild-Seiten):
        → kind = "vision_lv"  (Eimer "braucht Vision")
        → NICHT automatisch feuern. Erst per allow_vision-Opt-in (wie extract-plan) →
          extract_lv_via_vision → kind="lv". Ohne Opt-in: als "braucht Vision (kostet)" melden.
        → geht NIE an extract_doc.
 3. braucht_vision == False (sauberer Text):
        → extract_all() zählen: >= SCHWELLE plausible Positionen → kind="lv" (gratis)
        → sonst → extract_doc() (LLM) → kind="doc"
 4. Discriminated Union weiterhin: { "kind": "lv"|"doc"|"vision_lv"|"skip", ...payload..., "quelle" }
```

**Das löst zwei Probleme strukturell:** (1) kaputt-Text-PDF landet **nie** still als Doc-Müll;
(2) keine heimlichen Vision-Kosten auf einen ganzen Stapel — der teure Weg ist pro Datei
opt-in, genau wie `extract-plan` es schon vorlebt.

**Rest-Lücke (ehrlich):** ein **gescanntes Dokument** (z. B. Bild-Bodengutachten) triggert
`braucht_vision` ebenfalls und landet im „braucht Vision"-Eimer; die Vision-LV-Extraktion
liefert dann ~0 Positionen → als `skip` markieren (echtes OCR-Doc = Stufe 3, nicht in Scope).

**Korrektur zu §9:** Deploy = **systemd** (`sudo systemctl restart mops-api`), NICHT manuelles
uvicorn/setsid — der Dienst läuft als `mops-api.service`.

---

## 5) iOS-Änderung

- **`MopsClient.extractAuto(pdf:filename:) -> AuswertungsErgebnis`** mit
  `enum AuswertungsErgebnis { case lv(ExtractPlanResult); case doc(ExtractDocResult); case skip(String) }`,
  dekodiert aus dem `kind`-getaggten JSON (Decode-Logik von `extractPlan`/`extractDoc` wiederverwenden).
- **`starteUnterlagenAuswertung`** ruft künftig `extractAuto` (statt nur `extractDoc`) und
  sortiert die Ergebnisse in zwei Eimer: `lvErgebnisse: [ExtractPlanResult]` und
  `docErgebnisse: [ExtractDocResult]` (+ `skips: [String]`).
- **Kombinierte Review** (eine Ansicht, zwei Abschnitte — oder zwei Schritte):
  - **„Leistungsverzeichnisse (N)"** → `ExtractPlanMapper.toParsed` → dieselbe Review-Liste
    wie `LVImportView` (Auswahl-Häkchen) → „Übernehmen" ruft die bestehende `importSelected`-Logik.
  - **„Dokumente (M)"** → die `UnterlageAuswertungView`-Darstellung (aus dem gestrigen Feature) →
    „Speichern" persistiert nach `extras.auswertungen`.
  - **„Übersprungen (K)"** → Hinweis (Zeichnung/Vision, Stufe 3).
- **Die zwei Knöpfe zusammenlegen:** „Unterlagen auswerten" wird der Haupteinstieg. Der reine
  „PDF in LV importieren"-Weg (inkl. JSON-Datei-Import) bleibt als **Direkt-/Fallback-Weg**
  erhalten (z. B. wenn man gezielt nur ein LV oder eine extern erzeugte JSON einspielt).

---

## 6) Human-in-the-Loop (unverändert Pflicht)
- **LV** → Auswahl-Review vor dem Schreiben (Geld!). Nichts wird ungeprüft zu `LVPosition`.
- **Dokument-Fakten** → Auswahl beim Speichern (leicht, Notizen).
- Ergebnis immer als *Entwurf, geprüft* — konsistent mit `mengenQuelle`-Philosophie.

---

## 7) Offene Punkte / Nicht-Ziele
- **Schwelle** (ab wie vielen Positionen = LV?) am echten Material tunen — Fixtures:
  `aura125-lv-1.PDF` (→ „lv"), ein Bodengutachten/Wohnflächen-PDF (→ „doc").
- **Nicht-Ziel:** kein Auto-Speichern von LV-Positionen (bleibt Review).
- **Nicht-Ziel:** keine neue LLM-Anbindung — vorhandenes Setup wiederverwenden.
- **Abhängigkeit:** C1Pdf-LVs brauchen erst den Vision-Fallback (eigene Spec), sonst werden sie
  nicht als LV erkannt.

## 8) Sequenzierung (klein anfangen)
1. **Box `/extract-auto`** (try-plan-first + Schwelle), gegen die zwei Fixtures getestet — ohne
   iOS. Beweist die Klassifizierung.
2. **`MopsClient.extractAuto`** + Ergebnis-Enum.
3. **Kombinierte Review** (LV-Abschnitt = bestehende Review; Doc-Abschnitt = bestehendes
   Speichern). Ein Screen, zwei Abschnitte.
4. Knöpfe zusammenlegen; Direkt-LV-/JSON-Weg als Fallback behalten.
5. **Drift-Regel:** neuer Workflow → `Resources/Knowledge/app_bedienung.yaml` mitziehen.

## 9) Rahmen / Regeln
- Vor jedem Patch `.backup_*`. **Kein Push / kein PR ohne Andreas' OK.** Conventional Commits.
- Box-Deploy per Geländebrücke-Runbook (uvicorn manuell, `setsid` + SSH ~8 s offen halten).
- Trailing-Dot im Projektnamen → Pfade quoten. Simulator iPhone 17 Pro Max / iOS 26.2.
