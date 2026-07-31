# HANDOFF — Dokument-Auswertungen speichern & wieder aufrufen (+ Bonus: Fakten in der Ist-Übersicht)

> Selbsttragend. Du (Codi/Codex) siehst die auslösende Unterhaltung NICHT — alles steht hier.
> Bei Widerspruch Doku↔Code gilt der Code; dann kurz notieren, was abwich.
> Mittelgroßer Schritt, sauber in 3 Teile (+ optionaler Bonus) zerlegt.

## 0. Warum

Andreas hat alle PDFs eines Projekts auf einmal per „Unterlagen auswerten" (Stufe 2,
`/extract-doc`) ausgewertet — Ergebnis sah gut aus. **Aber:** Die Dokument-Auswertung
(`ExtractDocResult`: Bodengutachten, Wohnfläche, Bebauungsplan, Erschließung) wird nur
**angezeigt und dann weggeworfen** (`UnterlageAuswertungView` ist bewusst read-only,
Kommentar „kein Ziel-Entity zum Einbuchen"). Schließt man die Ansicht, ist die Auswertung
weg → beim nächsten Blick muss der Mops (Internet + Zeit + Token) alles neu lesen.

Zum Vergleich: **LV-Auswertungen** (`/extract-plan`) werden gespeichert (als `LVPosition`).
Nur die **Dokument-Fakten** haben kein Zuhause. Genau die Lücke schließen wir — die
Stufe-2-Spec (`docs/Stufe2-Dokumenten-Extraktion.md` §7) hatte das schon vorgesehen.

**Ziel (Andreas: „beides + Bonus"):**
1. **Cache** — Auswertung speichern, nicht neu rechnen müssen.
2. **Projekt-Datensatz** — die Fakten am Event nachschlagbar behalten.
3. **Bonus** — Kern-Fakten im Kopf der Baustellen-Ist-Übersicht zeigen.

## 1. Ausgangslage (verifiziert 8.7.2026)

- **Ablage-Muster:** `EventExtrasPayload` (`Views/EventDetailView.swift:10`, `Codable`) —
  trägt schon `houseProject`, `importHerkunft`, `bauphasen`. `laden(aus:)` / `speichern(in:)`
  bei `:42/:47`. **Kein Core-Data-Feld, keine Migration.**
- **Ergebnis-Modell:** `ExtractDocResult` (`Models/ExtractDocResult.swift`) ist `Codable,
  Identifiable` (`id == quelle`), Felder: `status, quelle, doctypeErkannt, confidence,
  felder: JSONValue, model, meldung` (+ Helfer `doctypeLabel`, `doctypeSymbol`).
- **`JSONValue`** (`Models/JSONValue.swift:10`) ist voll `Codable` (beide Richtungen) +
  hat `skalarText` (skalarer Text) → `felder` round-trippt sauber in extras.
- **Anzeige-View:** `UnterlageAuswertungView(ergebnisse: [ExtractDocResult], fehler: [String])`
  — read-only, Toolbar nur „Fertig" (dismiss). Rendert `felder` generisch über `zeilen(fuer:)`.
- **Aufruf-/Zustand in EventDetailView:** Sheet-Aufruf bei `:455`
  `UnterlageAuswertungView(ergebnisse: auswertResults, fehler: auswertFehler)`; Button-Bereich
  „Unterlagen auswerten" bei `:1022`. `auswertResults`/`auswertFehler` sind transiente `@State`.

## 2. Änderung — Teil A: Modell (klein)

In `Views/EventDetailView.swift` neben den anderen extras-Structs:
```swift
struct GespeicherteAuswertung: Codable, Identifiable {
    var ergebnis: ExtractDocResult
    var gespeichertAm: Date
    var id: String { ergebnis.quelle }   // Dedup-Schlüssel = Dateiname
}
```
`EventExtrasPayload` erweitern (Default nil → abwärtskompatibel mit bestehenden extras):
```swift
var auswertungen: [GespeicherteAuswertung]? = nil   // gespeicherte /extract-doc-Ergebnisse
```

## 3. Teil B: Speichern in `UnterlageAuswertungView` (Human-in-the-Loop)

Die View bleibt für Anzeige gleich, bekommt aber Auswahl + optionale Speichern-Aktion:
- **Auswahl:** `@State private var selektiert: Set<String>` (Dateinamen/`quelle`), initial
  **alle** ausgewählt. Pro `dokumentSection` ein Toggle/Häkchen (welche Auswertungen behalten).
- **Speichern-Closure (optional):** `let onSpeichern: (([ExtractDocResult]) -> Void)?` —
  wenn gesetzt, ein Toolbar-Button **„Speichern"** (`.confirmationAction`, orange), der
  `onSpeichern(ausgewählte)` ruft und dann `dismiss()`. „Fertig" bleibt als Schließen-ohne-Speichern.
- **Re-Ansicht-Modus:** wird die View für **schon gespeicherte** Auswertungen geöffnet, wird
  `onSpeichern = nil` übergeben → **kein Speichern-Button, keine Häkchen** (reine Ansicht).
- Den read-only-Doc-Kommentar (Zeilen ~16–18) anpassen: die Fakten haben jetzt ein Zuhause
  (extras), die View kann speichern *und* nur anzeigen.

## 4. Teil C: Persistenz + Wieder-Aufruf in `EventDetailView`

**Speichern (onSpeichern übergeben):** ausgewählte Ergebnisse in `extras.auswertungen`
mergen — **Dedup/Update über `quelle`** (dasselbe PDF erneut ausgewertet → ersetzt den
alten Eintrag, nicht duplizieren), `gespeichertAm = Date()`:
```swift
onSpeichern: { neue in
    var liste = extras.auswertungen ?? []
    for r in neue {
        liste.removeAll { $0.id == r.quelle }
        liste.append(GespeicherteAuswertung(ergebnis: r, gespeichertAm: Date()))
    }
    extras.auswertungen = liste.sorted { $0.ergebnis.quelle < $1.ergebnis.quelle }
    extras.speichern(in: event)
    try? viewContext.save()
}
```
**Wieder-Aufruf:** im „Unterlagen"-Bereich (nahe `:1022`) einen Abschnitt/Eintrag
**„Ausgewertete Unterlagen (\(extras.auswertungen?.count ?? 0))"** — nur sichtbar wenn >0.
Tippen öffnet `UnterlageAuswertungView(ergebnisse: gespeicherte.map(\.ergebnis),
fehler: [], onSpeichern: nil)` → **ohne Mops-Aufruf**, reine Ansicht. Optional pro Eintrag
Swipe-to-Delete (aus `extras.auswertungen` entfernen + speichern).

## 5. Bonus — Fakten im Kopf der Ist-Übersicht (optional, zuletzt)

In `BaustellenIstUebersichtView` (`kopf`, nach den Herkunft-Chips) eine kompakte Zeile
„Aus Unterlagen" mit 2–4 Kern-Fakten aus `extras.auswertungen`. Pro Doctype die Headline
(nur zeigen, wenn vorhanden — `felder` ist `JSONValue`, mit `skalarText` bzw. Pattern-Match
`if case .object(let d) = felder`):
| Doctype (`doctypeErkannt`) | Feld-Key | Chip |
|---|---|---|
| `bodengutachten` | `bodenklassen[0]` | „Bodenklasse: BKL 4–6" |
| `wohnflaeche` | `wohnflaeche_gesamt_m2` | „Wohnfläche: 112,8 m²" |
| `bebauungsplan` | `zone` / `grz` | „Zone WA2 · GRZ 0,4" |
| `erschliessung` | `medien.count` | „Erschließung: 4 Medien" |
Tipp: kleiner Helfer `fakt(ausDoctype:key:) -> String?` (findet das passende
`ExtractDocResult`, liest den Key). Fehlt der Doctype/Key → Chip weglassen (nie „—" zeigen).
Ggf. eine winzige `JSONValue`-Convenience (`subscript(String) -> JSONValue?`) ergänzen, wenn
das Pattern-Matching sonst zu laut wird.

## 6. Definition of Done
- Speichern in `UnterlageAuswertungView` (Auswahl + Button); `EventExtrasPayload.auswertungen`
  persistiert; „Ausgewertete Unterlagen"-Abschnitt öffnet gespeicherte Ergebnisse **ohne Mops**.
- Round-trip-Test (Swift Testing): `EventExtrasPayload` mit `auswertungen` → JSON → `laden` →
  gleiche Werte; Dedup: dasselbe `quelle` zweimal gespeichert → **ein** Eintrag (der neuere).
- Bonus (falls gebaut): Ist-Übersicht-Kopf zeigt vorhandene Fakten, keine „—"-Leerchips.
- Build grün (§8).
- **Drift-Regel PFLICHT:** neue sichtbare UI (Speichern-Button, „Ausgewertete Unterlagen",
  Fakten-Zeile) → `Resources/Knowledge/app_bedienung.yaml` ergänzen.

## 7. Regeln
- Vor Patch `.backup_*` (gitignoriert). **Kein Push / kein PR ohne Andreas' OK.**
- Conventional Commit, z. B. `feat: Dokument-Auswertungen speichern & wieder aufrufen`.
- Deutsch für Domänen-Begriffe, iOS 17+. `Date()` ist im App-Code ok.

## 8. Build & Test (Trailing-Dot — Pfade quoten)
```bash
xcodebuild test -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## 9. NICHT in Scope
- Kein Umbau der `/extract-doc`-Route oder des Mopsen (Backend bleibt).
- Kein Einbuchen der Doc-Fakten als LV-Positionen (andere Baustelle).
- Kein PDF-Export der Auswertung (evtl. später).
- Der Vision-Fallback (C1Pdf) ist ein **separater** offener Auftrag
  (`docs/CODEX-AUFTRAG-Vision-Fallback-C1Pdf.md`) — hier nicht anfassen.
