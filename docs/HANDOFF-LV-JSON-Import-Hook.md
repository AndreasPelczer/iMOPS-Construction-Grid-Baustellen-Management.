# HANDOFF — LV-Import aus JSON-Datei (ExtractPlanResult) für Codex

> Selbsttragend. Du (Codex) siehst die auslösende Unterhaltung NICHT — alles steht hier.
> Bei Widerspruch Doku↔Code gilt der Code; dann kurz notieren, was abwich.
> Kleiner, gut abgegrenzter Auftrag (~40–60 Zeilen Code).

## 0. Warum

Manche LV-PDFs (Town & Country, Export „ComponentOne C1Pdf") haben einen **kaputten
Text-Layer** → der Mops kann sie per Textextraktion nicht lesen. Solche LVs werden
extern per Vision zu **JSON im `ExtractPlanResult`-Format** gemacht (Beispiel liegt:
`~/Desktop/mopsss/LV/aura125-lv.json`, 241 Positionen). Es fehlt nur der Weg, so eine
**JSON-Datei in die App zu laden**. (Der zugehörige Backend-Fix — Vision-Fallback im
Mops — ist eine eigene Spec: `docs/Stufe2-OCR-Vision-Fallback-Spec.md`. Dieser Handoff
ist NUR der iOS-Datei-Import.)

## 1. Ausgangslage — was schon existiert (nichts doppelt bauen!)

Alles in `Views/LVImportView.swift`, Stand Branch `codex/lv-baustein-search`:
- **Review-Modell** `ParsedLVPosition` (in `Service/LVPDFImporter.swift:7`) — Felder
  posNr, bezeichnung, menge, einheit, isSelected, confidence, kostenGruppe, artikelNummer,
  lieferant, quellDateiName, quellDateiURL.
- **Mapper** `ExtractPlanMapper.toParsed(_ result: ExtractPlanResult) -> [ParsedLVPosition]`
  (`Service/ExtractPlanMapper.swift:52`) — genau das brauchen wir, nur mit Daten aus einer
  Datei statt vom Endpoint.
- **Mops-Weg als Vorlage** `parsePDFsViaMops(urls:)` (`LVImportView.swift:259`) — Muster:
  `Data(contentsOf:)` → Ergebnis → `toParsed` → `quellDateiName/URL` nachtragen →
  `parsedPositions.append(...)` → Fehler in `parseError`/`showError`.
- **Import in die DB** `importSelected()` (`LVImportView.swift:290`) — schreibt jede
  ausgewählte `ParsedLVPosition` in eine `LVPosition` am `event`. **Unverändert nutzbar.**
- **Picker** `PDFDocumentPicker` (`LVImportView.swift:318`) — `UIDocumentPicker` mit
  `[UTType.pdf]`, kopiert in tmp (Security-Scope). Als Vorlage für den JSON-Picker.
- **Quellen-Umschalter** `importQuelle` (enum mit `.lokal` / `.mops`) steuert in
  `handlePicks(urls:)` (`LVImportView.swift:240`), wohin die Picks gehen.
- **Datenmodell** `ExtractPlanResult` (`Models/ExtractPlanResult.swift`) — Codable:
  `{ metadata, lv_positionen[], bestellliste[], etiketten }`. Dekodiert heute mit nacktem
  `JSONDecoder()` (kein snake-case) → Top-Level `lv_positionen` (snake), innere Felder
  **camelCase** (`posNr`, `bezeichnung`, `einheit`, `menge`, `kg`, `quelle`). Genau so
  ist die Beispiel-JSON aufgebaut.

## 2. Die Änderung (klein)

**a) JSON-Picker** — neue `struct JSONDocumentPicker` analog zu `PDFDocumentPicker`,
aber `forOpeningContentTypes: [UTType.json]` (Fallback `UTType(filenameExtension: "json")`).
tmp-Kopie + Security-Scope 1:1 übernehmen. `allowsMultipleSelection = true` (mehrere LVs).

**b) Einstieg** — die einfachste Variante: einen dritten Fall `.jsonDatei` zu `importQuelle`
hinzufügen ODER (weniger invasiv) einen eigenen Button **„LV aus JSON-Datei"** im
Import-Screen, der `showJSONPicker = true` setzt und den `JSONDocumentPicker` als Sheet zeigt.
Wähle die Variante, die zum bestehenden UI-Aufbau passt (schau in den `body` von
`LVImportView` — wenn dort schon ein Picker über `importQuelle` gesteuert wird, füge den
Fall dort ein).

**c) Handler** `importJSONFiles(urls: [URL])` — Muster von `parsePDFsViaMops` spiegeln,
aber lokal dekodieren statt Mops rufen:
```swift
private func importJSONFiles(urls: [URL]) {
    guard !urls.isEmpty else { return }
    isParsing = true
    Task {
        var collected: [ParsedLVPosition] = []
        var letzterFehler: String?
        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let result = try JSONDecoder().decode(ExtractPlanResult.self, from: data)
                var parsed = ExtractPlanMapper.toParsed(result)
                for i in parsed.indices where parsed[i].quellDateiName == nil {
                    parsed[i].quellDateiName = url.lastPathComponent
                    parsed[i].quellDateiURL  = url
                }
                collected.append(contentsOf: parsed)
            } catch {
                letzterFehler = "‘\(url.lastPathComponent)’ ist keine gültige LV-JSON "
                              + "(erwartet ExtractPlanResult): \(error.localizedDescription)"
            }
        }
        await MainActor.run {
            isParsing = false
            if collected.isEmpty {
                parseError = letzterFehler ?? "Keine Positionen in der JSON gefunden."
                showError = true
            } else {
                parsedPositions.append(contentsOf: collected)
            }
        }
    }
}
```
(Falls `parsePDFsViaMops` bereits im MainActor-Kontext ist, den `await MainActor.run`-Wrap
weglassen und es genauso machen wie dort — konsistent mit dem bestehenden Stil bleiben.)

**d)** `importSelected()` **NICHT anfassen** — es verarbeitet `ParsedLVPosition` schon.

## 3. Stolpersteine

- `ExtractPlanResult` verlangt beim Dekodieren **alle vier Top-Level-Felder** (`metadata`,
  `lv_positionen`, `bestellliste`, `etiketten`) — die Beispiel-JSON hat alle. Wenn künftige
  hand-erzeugte JSONs `bestellliste`/`etiketten` weglassen, schlägt der Decode fehl. Optional
  robuster machen: in `ExtractPlanResult` einen `init(from:)` ergänzen, der `bestellliste`
  und `etiketten` als leer defaulted (`decodeIfPresent`). **Nur wenn einfach** — sonst
  Anforderung „vollständige JSON" akzeptieren und im Fehlertext nennen.
- `UTType.json` braucht `import UniformTypeIdentifiers` (steht ggf. schon in der Datei).
- Große LVs (241 Positionen) → die Review-Liste sollte in einer `List`/`LazyVStack` liegen
  (ist sie vermutlich schon). Kurz gegenprüfen, dass 241 Zeilen flüssig scrollen.

## 4. Definition of Done

- Button/Quelle „LV aus JSON-Datei" vorhanden → JSON wählen → Review-Liste füllt sich →
  Auswahl → „Importieren" legt `LVPosition`en am `event` an (über das bestehende
  `importSelected()`).
- **Verifikation mit Fixture:** `~/Desktop/mopsss/LV/aura125-lv.json` importieren, alle
  auswählen → das Event hat **241** neue `LVPosition`s; Stichprobe: `03.01.02
  Bodenplattenbeton 78 m²`, `14.02.28 PEDOTHERM Heizestrich 60,883 m²`.
- Build grün (Befehle siehe §6).
- **Drift-Regel (Pflicht):** Das ist eine sichtbare UI-Änderung (neuer Import-Weg) →
  passenden Eintrag in `Resources/Knowledge/app_bedienung.yaml` ergänzen, sonst lügt die
  Bedienungshilfe.

## 5. Regeln

- **Kein Push / kein PR ohne Andreas' ausdrückliches OK.** Commit auf dem Branch ist ok.
- Vor Patches an bestehenden Dateien `.backup_*` anlegen (gitignoriert).
- Conventional Commits (`feat: LV-Import aus JSON-Datei (ExtractPlanResult)`).
- Deutsch für Domänen-Begriffe, iOS 17+, kein neuer UIKit-Mix außer dem Picker (der ist
  schon UIViewControllerRepresentable — Muster von `PDFDocumentPicker` übernehmen).

## 6. Build & Test (Trailing-Dot — Pfade quoten)

```bash
xcodebuild -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 7. NICHT in Scope

- Kein Backend/Mops-Änderung (das ist die andere Spec).
- Keine automatische Format-Erkennung, kein CSV/XLSX — nur `ExtractPlanResult`-JSON.
- Kein Umbau der Review-Liste oder von `importSelected()`.
