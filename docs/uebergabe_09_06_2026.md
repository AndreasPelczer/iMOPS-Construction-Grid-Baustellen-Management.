# Übergabe — Dienstag, 09.06.2026

*Ein Mopsgetier-Tag mit Mantel und Degen. Nebel am Morgen, Drache am Nachmittag.*

## Was gelaufen ist (gestern Abend + heute)

### iMOPS (iOS) — alle PRs gemergt
- **#59 Screenshot-Harness „Codis Augen"** — `scripts/snapshot.sh` + `App/SnapshotHostView.swift` (DEBUG). UI vor dem PR sichtbar. Hat sich sofort bewährt (doppeltes Lineal in 5.2.1 entdeckt).
- **#61 Welle 5.2.1 — Fortschritt-Ableitung** (Option C): gemessen verdrängt geschätzt, ohne zu überschreiben (R1, Kap 4); Mehrmenge >100 % ehrlich; `ZeilenFortschritt`-Balken (blau/grün/Lineal vs. orange/Stift).
- **Lösch-Sicherheit (#62 → #63 → #65 → #66), in 4 Runden am iPhone gehärtet:**
  - **#62** LV-Position: kein Full-Swipe + Bestätigung + Folgen benennen (`loeschFolgen`).
  - **#63** Mängelliste: gleicher Schutz (inkl. „(inkl. Foto)"-Hinweis).
  - **#65** `.alert` statt `.confirmationDialog` — die rendert am Gerät als **Popover** und blendet „Abbrechen" aus.
  - **#66** Swipe-Knopf **ohne** `role: .destructive` (rot via `.tint(.red)`) — sonst animiert SwiftUI die Zeile vorzeitig raus.
  - **Am iPhone bestätigt: „sauber."** Lehre dokumentiert in der Memory `destructive-delete-safety`.

### mops-api (Backend) — #20 gemergt + **DEPLOYED + live verifiziert**
- **BuildIQ-Klassifikation läuft jetzt über den Prof (Claude)** statt llama3.2:3b. `classify-material._generate()` bevorzugt Claude (neue `ClaudeClient.complete_json`), **Ollama-Fallback**. **iOS unverändert** (gleicher Endpoint).
- **Live-Beweis:** „Sp-TT-Decken + Beton C30/37 + Wandbaustein" → **KG 350 Decken (korrekt), 3,8 s** — vorher llama „KG 370 Einbauten (falsch), ~15 s".
- **Entscheidung:** Prof, bis €50k für ein stärkeres lokales LLM da sind („wenn der Mops Steroide bekommt").
- **Deploy-Lehre:** `pkill -f "uvicorn api.main"` trifft die eigene SSH-Shell → **`fuser -k 8080/tcp`** nutzen (Gotcha #5).

### BuildIQ „das Monster" — diagnostiziert: war eine Eidechse
- Statische Analyse + Bild-Pipeline-Probe (10 echte Bilder): **kein Crash**, OCR robust. Der echte Punkt war die **Klassifikations-Qualität** — jetzt via Prof gelöst.
- ⚠️ **Datenhoheit-Trade-off jetzt live:** Lieferschein-OCR (ggf. mit Bauherr-Name/Adresse) geht zum Prof in die Cloud. Bewusst entschieden; Feinschliff-Option offen (nur Material-Schnipsel senden).

### Neue Idee festgehalten: Genehmigungs-Mappe
- Pro Baustelle: Dokument-Ablage + Pflicht-Komponenten-Checkliste; Item 🟢 wenn PDF abgelegt → alle grün = **„Roter Punkt" (baufrei)**. **Vertiefung von Welle 9** (kannte „Baugenehmigung" schon als ein Ampel-Item). Memory: `genehmigungs-checkliste`.

## Aktueller Stand
- **iMOPS main:** Harness + 5.2.1 + komplette Lösch-Sicherheit drin. Keine offenen PRs.
- **mops-api:** Prof live auf der Box (Health 200), main gesynct.
- Lokale Repos sauber, alle gemergten Branches gelöscht.

## Plan für Donnerstag, 11.06. (iMOPS-Optionen)
> Mittwoch 10.6.: **neues Projekt** mit dem Mops (Andreas überrascht mit den Details / dem ersten Sahnestückchen). Donnerstag je nach Lust + neuem Projekt:

1. **Welle 5.3 — BuildIQ-Mengen-Erkennung** (füllt `Aufmass.fotoData` + `quelle = .buildiq`). **Jetzt sinnvoll**, da die Klassifikation über den Prof korrekt ist.
2. **Genehmigungs-Mappe** (Welle-9-Zweig) — wenn der Hebel weiterjuckt.
3. **Datenhoheit-Feinschliff** — nur Material-Schnipsel statt ganzem Lieferschein an den Prof (DSGVO).
4. Kleinkram: `OCRService` `recognitionLanguages = ["de-DE"]` (bessere deutsche OCR).

**Stehende Regeln:** erst diagnostizieren, dann fixen · am echten Gerät testen · nie ohne OK pushen · Buch-Kapitel in jeder Commit-Message · keine Kundendaten ins Repo.
