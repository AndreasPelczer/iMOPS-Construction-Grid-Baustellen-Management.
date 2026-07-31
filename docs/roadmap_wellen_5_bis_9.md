# Roadmap Wellen 5–9 — konsolidiert

**Stand: 8.6.2026** · Basis: Code-Durchsicht aller fünf Wellen (Branch `fix/mangel-coredata-entity`)
Leitsatz (Andreas, 7.6.): *„Darf nicht vergessen das was vorbereitet ist auch zu nutzen."*

---

## Kernerkenntnis

Es gibt **ein gemeinsames Fundament**, das zwei Wellen gleichzeitig freischaltet:
**LVPosition um `istMenge` + Herkunfts-Kennzeichen (gemessen/geschätzt) erweitern.**

- Welle 5 braucht es für den Soll/Ist-Abgleich
- Welle 9 braucht es für „Schätzwerte andersfarbig"
- Der Import (ExtractPlanMapper) hat das Kennzeichen heute schon (`quelle: "schaetzung"` → Confidence 0.6), **wirft es aber nach dem Import weg** — es wird nicht in Core Data persistiert. Das ist die billigste große Verbesserung im ganzen Plan.

⚠️ Bei jedem neuen Core-Data-Feld/Entity: Entity-Checkliste beachten (`@objc(Name)` oder `.Name`, inverse Relationships korrekt) — sonst Crash bzw. Zähler=0.

---

## Welle 5 — BuildIQ Stufe 2 (Soll/Ist-Abgleich)

| 🟢 Schon im Code | 🟡 Muss gebaut werden |
|---|---|
| Kamera-Scan + Vision-OCR (`Views/BuildIQView.swift`) | `istMenge`, `erfassungsDatum`, `erfasstDurch` auf LVPosition (Core Data!) |
| Klassifikation läuft **lokal über die Box** (`/classify-material`, 180s-Timeout) — Gemini-Altlast ist raus | Verbindung BuildIQ → LVPosition (heute endet das Ergebnis am Auftrag: nur KG-Nummer wird gesetzt) |
| `BuildIQResult` (KG-Nr, Bezeichnung, Konfidenz, Begründung) | Erfassungs-UI für Ist-Mengen pro Position |
| Eigener Tab 7 mit Landing + Hilfe | Abgleich-Ansicht: Soll (`LVPosition.menge`) vs. Ist, Abweichung rot |
| DIN-276-Katalog (120+ KG) komplett | |

**Aufwand: ~1–2 Wochen.** Kleinster Brocken mit größtem Hebel — liefert die ersten **gemessenen** Werte ins System.
**Aufräumer nebenbei:** Hinweis „GEMINI_API_KEY in Secrets.plist" in `BuildIQHelpView.swift:465` ist verwaist → raus.

---

## Welle 6 — Kalkulations-Schicht

**Überraschung der Durchsicht: ~70 % fertig, kein Torso.** Die Tiefenkalkulation funktioniert durchgängig (Material+Lohn+Gerät → EK → W&G/BGK-Zuschläge → VK → Gesamtpreis, mit Speichern). GAEB X83/X84 rein UND raus, PDF-LV-Import, Material-CSV, Angebots-Vergleich pro Position mit Preis-Resolver (günstigstes Angebot schlägt Kalkulation).

| 🟢 Schon im Code | 🟡 Muss gebaut werden |
|---|---|
| `LVKalkulator` (EP-Engine), `MopsKalkulationsHelper` (REFA-Aufwandswerte von der Box, offline-fähig) | **Kostenzusammenfassung-View** — Button in `LVView.swift:157` existiert, das View dahinter **fehlt** (!) |
| `LVTiefenkalkulationView` voll funktional inkl. Speichern | **Stammdaten-UI** — Lohnsätze/Materialien/Geräte sind im `StammdatenSeeder` hartcodiert, keine Pflege-Oberfläche |
| Angebots-Vergleich + `AngebotsStore` (JSON) | KG-Summen-Ansicht (Kostengruppen aufsummiert) |
| GAEB-Import/-Export, PDF-Import/-Export, CSV | Excel/XLSX-Import Stammdaten (heute nur CSV/JSON) |
| Stammdaten-Modelle (Lohnsatz, KalkMaterial, PositionLohn/Geraet) | Mittellohn-Berechnung als Aggregat (heute nur Einzel-Lohnsatz pro Position) |
| | GAEB-X84-Preise beim Import auch in den AngebotsStore schreiben |

**Aufwand: ~2–3 Wochen.** „Verdichtung statt Neubau" stimmt exakt.
**Quick-Win zuerst:** das fehlende Kostenzusammenfassung-View — toter Button im UI ist Polier-sichtbar.

---

## Welle 7 — Geländebrücke (ex „Welle 6", umnummeriert 7.6.)

| 🟢 Schon im Code | 🟡 Muss gebaut werden |
|---|---|
| Python-Pipeline **vollreif & parametrisierbar**: `geodaten_fetch.py` (Adresse→DGM1-Kachel, mit SHA-Verify+Cache), `alkis_flurstueck.py`, `welle6_mustermann_cutfill.py` (IDW, Cut/Fill, Heatmap-PNG) — validiert am BV Mustermann, OK-BP deckungsgleich mit Vermesser | **Box-Endpoint** `/gelaende-analyse` (Adresse + Footprint rein → Cut/Fill, Schotter t, LKW-Fahrten raus) |
| `HouseConfigurator` + `HouseProjectGenerator`: Erdarbeiten sind als Bauphase + Masse schon drin (Kellerwand-Aushub `gf × 3,0 m³` pauschal), sogar das Berg-Icon existiert (`HouseConfiguratorView.swift:476`) | Adress-Feld im HouseConfigurator (fehlt heute komplett) |
| Baunebenkosten enthalten Vermessung + Baugrundgutachten (Pauschalen) | Pauschal-Aushub durch DGM-gerechnete Massen ersetzen, **als Schätzwert gekennzeichnet** (→ Welle-9-Farben) |
| | PDF-Aushub-Bericht (Python-Seite vorbereiten, App zeigt an) |

**⚠️ Architektur-Korrektur zu den Notizen:** Das iPad kann kein Python-Subprocess starten. Richtiger Weg = wie BuildIQ: **die Pipeline läuft als API auf der Mops-Box**, die App ruft sie auf. Datenhoheit bleibt im Heimnetz.
**Wichtig:** Die Python-Scripts liegen lokal in `~/Projekte/mops-extract-prototype/` und sind **nicht gepusht** → erster Schritt: ins mops-api-Repo überführen (vorher DSGVO-Grep: keine Kundendaten/Adressen einchecken!).

**Aufwand: ~2–3 Wochen** (Box-Endpoint ~1 Woche, App-Anbindung ~1–2). Server-Teil kann **parallel** zu Welle 5/6 laufen.

---

## Welle 8 — Heinze-Integration

| 🟢 Schon im Code | 🟡 Muss gebaut werden |
|---|---|
| **Nichts.** (Bestätigt: kein Treffer im Repo) | API-Vertrag klären: Was bietet Heinze überhaupt an (Produktdaten? Preise? Lizenz/Kosten?) |
| | Connector (sinnvollerweise auf der Box, nicht in der App) |
| | Ziel-Anbindung: Heinze-Preise → `KalkMaterial` / AngebotsStore (= füttert Welle 6) |

**Aufwand: nicht seriös schätzbar**, solange der API-Zugang ungeklärt ist — externe Abhängigkeit.
**Jetzt schon möglich (0 Code):** Recherche-Hausaufgabe — Heinze-API-Doku/Konditionen anfragen. Kostet nur eine E-Mail und entscheidet, ob die Welle 2 Tage oder 4 Wochen wird.

---

## Welle 9 — Voraussetzungs-Ampel

| 🟢 Schon im Code | 🟡 Muss gebaut werden |
|---|---|
| `AuftragChecklistItem` (JSON in `Auftrag.extras`, Done-Flag, Fortschritts-Ratio) | **Hierarchie fehlt komplett**: Es gibt nur Event(Baustelle) → Auftrag/LVPosition, flach. „Stockwerk" ist heute ein Freitext-String (`station: "EG Wohnung 3"`). Entscheidung nötig: echte Entities (Gebäude/Geschoss) **oder** leichtgewichtig strukturierte Felder |
| `AuftragStatus` (4 Zustände, farbig) + `AuftragProgressData` + Progress-Bar in `AuftragRowView` | Rollup-Service (`ReadinessManager`: Position→Geschoss→Gebäude→Baustelle, 🔴🟠🟢) |
| `KernelGuards`/`TheBrain`/`KernelArbeitsschritt`: Guard-Stack + Workflow-Engine mit Blockier-Mechanik (Fatigue, Brigade-Last, Whisper-Messages) — **die Freigabe-Logik existiert als Muster** | Voraussetzungs-Katalog (Plan da? Anzahlung? Statik? Material bestellt?) mit `prerequisiteIDs` |
| Geschätzt/Gemessen-Kennzeichen im Import (`ExtractEtiketten`, Confidence 0.6/0.95) | Kennzeichen **persistieren** (heute nach Import weg!) → gemeinsames Fundament mit Welle 5 |
| | Ampel-UI + „System fordert aktiv" (Whisper-Mechanik der KernelGuards wiederverwenden: *„Statik fehlt — Freigabe blockiert"*) |
| | Polier-Freigabe-Knopf, stückweise pro Ebene |

**Achtung:** TheBrain läuft heute **komplett entkoppelt von Core Data** (In-Memory, wird bei jedem Start neu geseeded). Für die Ampel muss der Guard-Mechanismus an echte Auftrags-/Positionsdaten gekoppelt werden — das ist der eigentliche Bauplatz dieser Welle.

**Aufwand: ~3–4 Wochen.** Größter Brocken, aber „Ausbau statt Neubau" stimmt: Status, Checkliste, Guards, Blockier-Muster sind alle da.

---

## Abhängigkeiten

```
LVPosition-Fundament (istMenge + gemessen/geschätzt-Flag)
        ├──→ Welle 5 (Soll/Ist braucht die Felder)
        └──→ Welle 9 (Schätzwert-Farben brauchen das Flag)

Welle 5 (Ist-Mengen)  ──→ Welle 9 („gemessen" schaltet Farbe um)
Welle 6 (Kalkulation) ──→ Welle 9 (Voraussetzung „Berechnung vollständig")
Welle 6 (KalkMaterial/Angebote) ←── Welle 8 (Heinze füttert Preise)
Welle 7 (Geländebrücke) ──→ HouseConfigurator → LV → Welle 6 (rechnet die Massen)
Welle 7 ──→ Welle 9 (DGM-Massen = Schätzwerte, andersfarbig)
```

## Reihenfolge + Zeitfenster (in Wochen, realistisch für Feierabend-Takt)

| # | Was | Fenster | Warum zuerst/dann |
|---|---|---|---|
| 0 | **LVPosition-Fundament** (Felder + Flag persistieren) | ~0,5 Wo | Schaltet W5 + W9 frei, kleinster Eingriff |
| 1 | **Welle 5** BuildIQ Soll/Ist | Wo 1–2 | Kleinster Brocken, erste Messwerte, sofort Polier-Nutzen |
| 2 | **Welle 6** fertig verdichten (Kostenzusammenfassung → Stammdaten-UI → KG-Summen → Mittellohn → XLSX) | Wo 3–5 | 70 % da; W9 braucht den Kalkulations-Status |
| ∥ | **Welle 7 Server-Teil** (Scripts → mops-api, Box-Endpoint) | parallel Wo 1–5 | Unabhängig von der App, andere Baustelle (Box) |
| ∥ | **Welle 8 Recherche** (Heinze-Konditionen anfragen) | sofort, 1 E-Mail | Externe Wartezeit früh starten |
| 3 | **Welle 9** Ampel (Hierarchie-Entscheid → Rollup → Katalog → UI → Freigabe) | Wo 6–9 | Baut auf W5-Messwerten + W6-Status auf |
| 4 | **Welle 7 App-Teil** (Adressfeld, DGM-Massen statt Pauschale) | Wo 9–11 | Andockt an fertige Ampel (Schätzwert-Farben) |
| 5 | **Welle 8** Connector | nach API-Klärung | Nicht schätzbar ohne Vertrag |

**Grobe Gesamtlinie: ~11 Wochen bis alle fünf Wellen stehen** (ohne Heinze-Connector). Puffer einplanen — Bauleiter-Alltag geht vor.

---

## Polier-Notizen

- **Risiko Doppelungen** (aus der Galaxie-Betrachtung): bestätigt, aber nicht akut. Kandidat für eine kalte Stunde: `AuftragStatus` vs. `ArbeitsschrittStatus` (zwei Status-Welten), `AngebotsStore` (JSON) vs. Core Data.
- **Welle-Nummern-Falle:** Die Geländebrücke heißt in alten Dateien noch `welle6_*` (`welle6_mustermann_cutfill.py` etc.) — Dateien NICHT umbenennen, nur wissen.
- **DSGVO vor jedem Push** der Geländebrücken-Scripts: grep nach echten Bauherren-Namen, Privat- und Grundstuecksadressen (Beispieldaten immer pseudonym!).
