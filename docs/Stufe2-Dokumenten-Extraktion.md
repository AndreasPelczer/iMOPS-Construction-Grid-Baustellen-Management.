# Stufe 2 — Dokumenten-Extraktion (Text-Docs → strukturierte Felder)

> Design-Spec, Stand 2026-07-03. Umsetzungsreif, noch nicht gebaut.
> Vorstufe: Stufe 1 (Mehrfach-PDF-Upload im LV-Import) ist gebaut.
> Nachstufe: Stufe 3 (Pläne per Vision) — **nicht** Teil dieser Spec.

## 1. Ziel & Abgrenzung

**Ziel:** Aus den *text-tragenden* PDFs eines Bauvorhabens automatisch die
LV-relevanten Fakten ziehen — genau das, was am 03.07. manuell (4 Prüf-Agenten)
aus dem BV Setiadji herausgeholt wurde, nur als Feature in der App.

**In Scope:** PDFs mit echter Textebene — Bodengutachten, Wohnflächen-/
Rauminhalt-Berechnung, Bebauungsplan-Textteil, Erschließungs-Datenblätter.

**Explizit NICHT in Scope (→ Stufe 3):** gezeichnete Pläne (Grundrisse, Ansichten,
Schnitte, Lagepläne). Die haben keine verwertbare Textebene → brauchen Vision.
Erkennung: hat `pdftotext` < ~200 Zeichen/Seite geliefert → als „Zeichnung, Stufe 3"
markieren, nicht an die Text-Pipeline geben.

## 2. Warum es diesmal geht (und wo die Intelligenz sitzt)

Diese Dokumente **haben** eine Textebene (heute verifiziert: Bodengutachten ~15k
Zeichen, WoFiV/BRI, B-Plan). Das lokale `llama3.2:3b` ist zu klein fürs Fach-Reasoning
→ die Extraktion läuft über die **schon vorhandene `/prof`→Claude-Brücke** im Mops.

> Arbeitsteilung wie bei der Geländebrücke: **Mops macht die Mechanik**
> (Text ziehen, Doctype raten, Prompt bauen), **Claude macht das Reasoning.**

## 3. Architektur

```
App (LVImportView / EventDetail)
   │  POST /extract-doc  (multipart: pdf + optional doctype-Hint)
   ▼
mops-api  (neue Route api/routes/extract_doc.py)
   │  1. pdftotext -layout  → Rohtext
   │  2. Doctype erkennen (Heuristik, s.u.) falls kein Hint
   │  3. Prompt bauen (doctype-spezifisches JSON-Schema)
   │  4. an /prof (Claude) schicken  ← bestehende Bridge wiederverwenden
   │  5. JSON validieren, zurückgeben
   ▼
App: Felder anzeigen → in Projekt/LV übernehmen (Mensch bestätigt)
```

- **Ort:** neue Route im `mops-api`-Repo, analog zu `api/routes/extract.py`
  (das `/extract-plan` macht). NICHT im iOS-Repo (nur Client).
- **Wiederverwenden:** die `/prof`-Route (Claude) existiert bereits
  (`feat: classify-via-prof`, Commit-Historie mops-api). Kein neuer LLM-Zugang nötig.
- **Betrieb:** Route wird beim uvicorn-Start mitgeladen; Deploy = neue Datei +
  Neustart der tmux-Session `mops` (siehe Geländebrücke-Runbook).

## 4. Endpoint-Contract

**Request** `POST /extract-doc`
- `doc_file`: UploadFile (PDF)
- `doctype` (optional, query): `bodengutachten | wohnflaeche | bebauungsplan | erschliessung | auto` (default `auto`)

**Response** `200` (Beispiel-Hülle):
```json
{
  "status": "success",
  "quelle": "Bodengutachten BV Setiadji.pdf",
  "doctype_erkannt": "bodengutachten",
  "confidence": 0.9,
  "felder": { ... doctype-spezifisch, s.u. ... },
  "meldung": "Aus PDF-Text extrahiert. Vor Verwendung prüfen — ersetzt kein Gutachten."
}
```
- `422` wenn kein/zu wenig Text (→ „vermutlich Zeichnung, Stufe 3").
- `502` wenn `/prof` nicht erreichbar (Claude down) — mit klarer Meldung.

## 5. Doctype-Erkennung (Heuristik, ohne LLM)

Auf dem Rohtext, case-insensitiv, erste 3000 Zeichen:
- `bodengutachten` ← „geotechni", „Kleinrammbohrung", „Bodenklasse", „Homogenbereich"
- `wohnflaeche` ← „WoFlV", „Wohnfläche", „Brutto-Rauminhalt", „BRI"
- `bebauungsplan` ← „Bebauungsplan", „Festsetzung", „GRZ", „Baugrenze"
- `erschliessung` ← „Hausanschluss", „DN ", „Regenrückhalt", „Schmutzwasser"
- sonst `auto` → Claude entscheidet den Typ mit.

## 6. Feld-Schemata je Doctype

*(Felder = genau die, die heute manuell verwertbar waren. Alle Werte mit Einheit,
`null` wenn nicht im Dokument.)*

**bodengutachten**
```
bodenklassen[]        // z.B. "BKL 4-6, teils 5-7"
schichtaufbau[]       // {schicht, tiefe_m, bodenart, tragfaehigkeit}
grundwasser           // {angetroffen: bool, bemessungsstand}
frosttiefe_m
gruendungsempfehlung  // Freitext + {variante, polster_m, sohlwiderstand_kN_m2}
abdichtung_lastfall   // "W1.1-E" | "W1.2-E + Dränage"
besonderheiten[]      // Hanglage, Verkarstung, Kontamination ...
```

**wohnflaeche**
```
wohnflaeche_gesamt_m2
raeume[]              // {geschoss, name, flaeche_m2}
bri_m3                // Brutto-Rauminhalt
nutzflaeche_m2
```

**bebauungsplan**
```
zone                  // "WA2"
grz, gfz
hoehen                // {wand_max_m, first_max_m}
dach                  // {formen[], neigung_grad, farben[]}
erdarbeiten           // {abgrabung_max_m, auffuellung_max_m, stuetzwand_max_m}
stellplaetze_pflicht
pflanzgebot
sonstige[]
```

**erschliessung**
```
medien[]              // {medium, dimension, laenge_m, anschlusspunkt, hinweis}
rueckstauebene_mNN
besonderheiten[]      // z.B. "20-kV-Leitung im Baufeld"
```

Die Schemata leben als Konstanten in der Route; der Claude-Prompt bekommt sie als
Ziel-JSON und die Anweisung „nur Werte, kein Norm-Volltext" (Lizenz-Regel wie
ExactMatchKnowledge).

## 7. Client-Integration (iOS)

- Einstieg B: neuer Button in `EventDetailView` / im Unterlagen-Bereich einer
  Baustelle: **„Unterlagen auswerten"** → Mehrfach-Picker (Stufe-1-Baustein
  `PDFDocumentPicker` wiederverwenden!) → pro PDF `/extract-doc`.
- Ergebnis: eine Review-Liste (analog `LVImportView.reviewList`) — Felder je
  Dokument, Mensch hakt ab, was ins Projekt übernommen wird.
- Ablage: strukturierte Felder als **Vorbemerkungen/Projekt-Notizen** und, wo es
  passt, als LV-Positionen (z.B. Bodengutachten → Erd-/Gründungs-Positionen mit
  vorbelegten Mengen). Herkunft je Feld über das schon vorhandene
  `quellDateiName`-Muster.
- **Human-in-the-Loop ist Pflicht** — nichts wird ungeprüft ins LV geschrieben.

## 8. Testplan (Fixtures = die Setiadji-Docs von heute)

| Fixture | Erwartet (Auszug) |
|---|---|
| `Bodengutachten BV Setiadji.pdf` | bodenklassen „BKL 4-6", frosttiefe 0.8 m, grundwasser.angetroffen=false, abdichtung „W1.1-E" |
| `250415_WoFiV…pdf` | wohnflaeche_gesamt 112,80 m², raeume enthält Wohnen 33,24 |
| `250415_BRI…pdf` | bri_m3 623,6 |
| `bebplan_klinge…pdf` | zone „WA2", stuetzwand_max 2,5 m, dach.neigung 14–50° |

Die erwarteten Werte stehen im heutigen LV-Dossier
(`~/Downloads/BV-Setiadji-Artanti_LV/`) — 1:1 als Soll nutzbar.

## 9. Sequenzierung (klein anfangen)

1. **Prototyp zuerst** (wie `gelaendebruecke.py` startete): Standalone-Skript in
   `~/Projekte/mops-extract-prototype/extract_doc.py`, das *eine* Bodengutachten-PDF
   → Rohtext → Claude → JSON macht. Lokal gegen die Setiadji-PDF getestet, **ohne**
   Box-Deploy. Beweist die Pipeline.
2. Prototyp → Route `/extract-doc` im mops-api, ein Doctype (`bodengutachten`).
3. Weitere Doctypes (wohnflaeche, bebauungsplan, erschliessung).
4. Client-Button + Review-Liste.
5. Übernahme ins LV/Projekt.

## 10. Kosten, Risiken, Nicht-Ziele

- **Kosten:** pro Dokument ~wenige Cent (Text ist billig). Explizit auslösen
  (Button), nicht automatisch bei jedem Upload → keine Token-Verschwendung.
- **Vertrauen:** Ausgabe immer als *Entwurf, prüfen* markieren. Mengen aus
  Gutachten sind Schätzgrundlage, keine Abrechnung.
- **Offline-Charakter:** Dieses Feature braucht Internet + Claude (`/prof`) —
  im UI ehrlich kennzeichnen, getrennt vom Offline-Bau-Wissen (ExactMatchKnowledge).
- **Nicht-Ziel:** Pläne/Zeichnungen (Stufe 3, Vision). Diese Pipeline erkennt sie
  nur und schiebt sie beiseite.

## Verbindung zu offenen Fäden
- Der Multi-Picker aus **Stufe 1** ist der Client-Baustein hier.
- Das **Footprint-Thema der Geländebrücke** (Hauslage in Vermessungs-DXF nachtragen)
  ist verwandt, aber eigenständig — gehört zu Stufe 3 (Geometrie), nicht hier.
