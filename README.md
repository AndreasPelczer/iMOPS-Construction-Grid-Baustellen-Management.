# iMOPS — Construction Grid · Baustellen-Management

**iOS-App (Swift / SwiftUI) für Bauleitung, Auftrags- und Baustellen-Management.**
Offline-First mit Core Data, MVVM, angebunden an einen eigenen LLM-Backend-Dienst
(„Mops"). Solo-Projekt von Andreas Pelczer — aus einer Gastro-/Catering-App
(GASTRO-GRID) schrittweise auf die Bau-Domäne umgebaut.

> „Code lügt nicht, Fantasie schon. Wir bleiben am Boden der Tatsachen, der Commits
> und der echten Baustelle."

| | |
|---|---|
| **Plattform** | iOS / iPadOS · Mac Catalyst · Deployment-Target **26.2** |
| **Sprache** | Swift 5, SwiftUI, MVVM |
| **Datenhaltung** | Core Data (Offline-First), Modell `test25B.xcdatamodeld` |
| **Dependencies** | nur **Yams** (YAML, via SPM) — kein weiteres Frontend-Framework |
| **Umfang** | ~188 Swift-Dateien · ~29.700 Zeilen · 77 Views · 49 Services · 17 Core-Data-Entities |
| **Backend** | separates Repo `mops-api` (FastAPI, Python) auf einer Heim-Box, via Cloudflare-Tunnel |

---

## Inhalt

1. [Was ist iMOPS](#was-ist-imops)
2. [Leitideen](#leitideen)
3. [Funktionsumfang](#funktionsumfang)
4. [Architektur](#architektur)
5. [Datenmodell](#datenmodell)
6. [Service-Schicht](#service-schicht)
7. [Wissensbasis (YAML)](#wissensbasis-yaml)
8. [Mops-Backend](#mops-backend)
9. [Kernel (Spike)](#kernel-spike)
10. [Build & Test](#build--test)
11. [Repo-Konventionen](#repo-konventionen)
12. [Stand der Wellen & Roadmap](#stand-der-wellen--roadmap)
13. [Dokumente & Übergaben](#dokumente--übergaben)

---

## Was ist iMOPS

iMOPS bündelt den Alltag der Bauleitung in einer App: **Leistungsverzeichnisse**
kalkulieren, **Aufmaße** und Ist-Mengen nachweisen, **Mängel** dokumentieren,
**Bautagesberichte** schreiben, **Aufträge** an Gewerke verwalten, **Pläne/CAD/DXF**
importieren und den **Erdaushub** aus einer Vermessung rechnen — dazu ein
**KI-Assistent** („Mops") für Fachfragen und die automatische Auswertung von
Bau-PDFs (Leistungsverzeichnisse, Bodengutachten, Wohnflächen, Bebauungspläne).

Die App ist **offline-first**: alle Kern-Daten liegen lokal in Core Data. Die
KI-/Auswertungs-Funktionen sprechen mit dem selbst betriebenen Mops-Backend; ist
es nicht erreichbar, funktioniert der Rest der App weiter, und ein Teil des
Fachwissens liegt sogar offline als lokale Wissensbasis vor.

---

## Leitideen

- **„Gemessen verdrängt geschätzt."** Jede Menge trägt ihre Herkunft (`mengenQuelle`:
  gemessen / geschätzt / manuell / Import). Geschätzte Werte werden sichtbar als solche
  markiert und weichen, sobald echte (gemessene/importierte) Daten vorliegen.
- **Soll vs. Ist.** Der Haus-Planer erzeugt eine **Soll-Übersicht** (Schätzung aus
  Haustyp). Die **Ist-Übersicht** einer echten Baustelle wird aus den *importierten*
  LV-Daten gebaut — dieselbe Optik, zwei Datenquellen.
- **Human-in-the-Loop.** KI-Auswertungen sind immer ein *Entwurf*, der geprüft und
  bewusst übernommen wird — nichts wird ungeprüft in die Daten geschrieben.
- **Lizenz-sauber.** In der Wissensbasis stehen nur Werte/Sachverhalte, **kein
  DIN-Norm-Wortlaut** (Beuth-Lizenz).
- **Deutsch in der Domäne.** Fachbegriffe im Code deutsch (`bauherr`, `kostenGruppe`,
  `aufmass`), Infrastruktur englisch.

---

## Funktionsumfang

### Baustellen & Übersicht
- **EventListView / EventDetailView** — Baustellen (Core-Data-`Event`) anlegen,
  verwalten und als Hub öffnen: LV, Mängel, Bautagesbericht, Chat, CAD, Zeitplan.
- **BaustellenKontrollzentrumView** — Kontrollzentrum mit Bau-Wissen-Chat & Haus-Konfigurator.
- **BaustellenIstUebersichtView** — Ist-Übersicht aus echten LV-Daten mit Reitern
  **Kosten** (nach DIN-276-Kostengruppe), **Massen** (nach LV-Titel), **Material**
  und **Zeitplan** (Bauzeitraum + manuell geplante Bauphasen).
- **AmpelCard / Voraussetzungs-Ampel** — Rot/Grün-Status „baufrei" pro Ebene.
- **WetterKarteView** — bau-relevante Wetterwarnungen (Regen/Frost/Wind).

### Leistungsverzeichnis & Kalkulation
- **LVView** — LV mit Gruppierung nach Kostengruppe / Dokument / Ebene.
- **LVTiefenkalkulationView** — Position kalkulieren aus Material + Lohn + Geräten + Zuschlägen.
- **LVKalkulationView / KostenübersichtView / GeschossKostenView** — Preis- und
  Kosten-Rollups (netto/MwSt/brutto), wahlweise nach Kostengruppe oder Gebäude/Geschoss.
- **AngebotsVergleichView** — Lieferanten-Angebote je Position vergleichen.
- **AufmassSheet** — Ist-Mengen-Nachweise (Aufmaße) mit Quelle & Zeitstempel.
- **GAEBImportView** — Import/Export im GAEB-Standard (X83/X84).
- **StammdatenPflegeView** — globale Kalkulations-Vorlagen (Löhne, Materialien, Geräte).

### Dokumenten-Import & KI-Auswertung
- **LVImportView** — Leistungsverzeichnisse aus **PDF** (Mops oder lokaler Parser) und
  aus **JSON** (`ExtractPlanResult`) importieren, inkl. Mehrfach-Auswahl und Review-Liste.
- **UnterlageAuswertungView** — ganze Projekt-Unterlagen (Bodengutachten, Wohnflächen-,
  Bebauungsplan-, Erschließungs-PDFs) per Mops auswerten → strukturierte Fakten als
  prüfbarer Entwurf.
- Beim Import wird die **DIN-276-Kostengruppe** heuristisch aus der Bezeichnung gesetzt,
  falls das Dokument keine liefert (`KGZuordnungsService`).

### Geländebrücke (Erdmassen)
- DXF-Vermessung hochladen → Backend rechnet per **IDW-Interpolation** Cut/Fill
  (Abtrag/Auftrag), Schotter, Trennvlies und LKW-Fuhren → Ergebnis als Card, PDF-Report
  und als LV-Positionen. Layer-Erkennung ist provider-flexibel (verschiedene Vermesser-Schemata).

### CAD & 3D
- **CADImportView / CADViewerView** — Import und 3D-Ansicht (USDZ, OBJ, DAE, FBX, STL,
  glTF, PDF, DXF, DWG, IFC) via SceneKit; SketchUp-Konvertierung über einen separaten Dienst.
- **HouseConfiguratorView** — Haus-Planer: Eingaben → Soll-Übersicht (Kosten/Material/Massen/Zeitplan).

### Doku, Mängel & Aufträge
- **BautagesberichtView** — Tagesbericht (Witterung, Team, Aufgaben, Mängel) mit PDF-Export.
- **MangelListeView / MangelErfassenView / MangelDetailView** — Mängel mit Fotos,
  Status, Fristen und PDF-Export.
- **AuftragDetailView / AddJobView** — Aufträge an Gewerke/Subunternehmer inkl.
  Fortschritt und Checklisten.
- **LieferantenBestelllisteView** — Bestellanfragen an Lieferanten (mit Mail-Integration, PDF).

### Bau-Wissen & KI-Assistenz
- **BauWissenView** — Fachfragen an den Mops (lokales LLM) bzw. per `/prof` an Claude/OpenAI;
  Quellen mit Score-Anzeige.
- **BuildIQView** — Kamera-/Vision-Scanner, der Material erkennt und auf eine LV-Position bucht.

### Hierarchie & Freigabe (Welle 9)
- **HierarchieVerwaltenView** — Bau-Hierarchie `Event → Gebäude → Geschoss → LVPosition`
  anlegen/umbenennen/sortieren.
- **FreigabeStatusView** — Ebenen-Freigabe & Voraussetzungs-Status (reine Anzeige, blockiert nichts).

### Stammdaten, Crew & Navigation
- **CrewPlanningView / EmployeeDetailView** — Mitarbeiter & Auslastung.
- **RootTabView** — Tabs Baustellen · LV · Mängel · Crew · Chat · Einstellungen
  (rollenabhängig sichtbar: worker / dispatcher / director).
- **GlobalSearchView** — globale Suche über Baustellen/LV/Mängel/Katalog/Aufträge.
- **SettingsView** — Server-URL, Firmendaten, API-Keys.

---

## Architektur

MVVM. Quellbaum liegt im Unterordner `iMOPS-Construction-Grid-Baustellen-Management./`:

```
iMOPS-Construction-Grid-Baustellen-Management./
├── App/            Entry-Point (iMOPSApp), AppSession (Rolle → sichtbare Tabs), Constants
├── Models/         Core-Data-Entities (+ Subclasses) und Domänen-Structs
│   └── test25B.xcdatamodeld
├── Views/          SwiftUI-Views (~77 Dateien)
├── ViewModels/     MVVM-ViewModels (@Observable, async/await)
├── Service/        Geschäftslogik & Exporter (~49 Dateien)
├── Kernel/         In-Memory-Spike (TheBrain, KernelGuards) — läuft parallel zu Core Data
└── Resources/
    └── Knowledge/  YAML-Wissensbasis (Fachwissen + App-Bedienung)
```

- **MVVM**, modernes Swift: durchgehend async/await, `@Observable` statt @Published-Overuse,
  Logging über `os.Logger`, Fehler als `LocalizedError`-Enums.
- **`extras`-Muster:** Event-Metadaten, die kein eigenes Core-Data-Feld brauchen, liegen als
  Codable-JSON-Blob (`EventExtrasPayload`) am Event — u. a. `checklist`, `houseProject`,
  `importHerkunft`, `bauphasen`, `auswertungen`. Vorteil: neue Felder ohne Core-Data-Migration.

> ⚠️ **Trailing-Dot:** Projekt-Ordner, `.xcodeproj` **und** Scheme enden buchstäblich auf
> einen Punkt (`iMOPS-Construction-Grid-Baustellen-Management.`). Kein Tippfehler — Pfade in
> der Shell immer quoten. Der Swift-Modulname (Punkt → `_`) ist
> `iMOPS_Construction_Grid_Baustellen_Management_` (relevant für `@testable import`).

---

## Datenmodell

Core Data, Offline-First. **17 Entities, komplett Bau-Domäne** (keine Gastro-Reste mehr):

`Event` (Baustelle) · `Auftrag` · `LVPosition` · `Aufmass` · `Gebaeude` · `Geschoss` ·
`Mangel` · `Geraet` · `KalkMaterial` · `Lohnsatz` · `Employee` · `Voraussetzung` ·
`PositionMaterial` · `PositionLohn` · `PositionGeraet` · `CDLexikonEntry`.

Beziehungen u. a.: `Event → gebaeude / geschosse / lvPositionen / maengel`,
`Geschoss → lvPositionen`, `Auftrag → event`, `LVPosition → material/lohn/geraet`.
Kern-Domänen-Structs (Nicht-Core-Data): `HouseProject`, `ExtractPlanResult`,
`ExtractDocResult`, `GelaendeResult`, `DIN276BaumKatalog`, `JSONValue`.

---

## Service-Schicht

~49 Services, nach Bau-Domäne geschnitten:

- **GAEB:** `GAEBImporter` / `GAEBExporter` (X83/X84-Ausschreibungsformat).
- **Kalkulation:** `LVKalkulator` (reine Preis-Engine: Material+Lohn+Geräte+Zuschläge),
  `AngebotsStore` (Lieferanten-Preise), `MopsKalkulationsHelper` (KI-Aufwandswerte).
- **DIN 276:** `DIN276KostenGruppe` / `DIN276BaumKatalog` (Katalog) + `KGZuordnungsService`
  (Keyword → Kostengruppe).
- **Mops-Anbindung:** `MopsClient` (HTTP), `ExactMatchKnowledge` (lokale YAML-Wissensbasis,
  Pre-Filter vor jedem LLM-Call), `BuildIQService` (Material-Klassifikation).
- **Dokumenten-Extraktion:** `ExtractPlanMapper` (`/extract-plan`-JSON → `LVPosition`),
  `LVPDFImporter` (lokaler PDF-Parser), Import-Herkunft-Persistenz.
- **PDF/Export:** `LVPDFExporter`, `BautagesberichtPDFExporter`, `MangelPDFExporter`,
  `LieferantenAnfragePDFExporter`, XRechnung-Export.
- **Geländebrücke:** DXF-Upload-Service → `/gelaendebruecke/calculate`.
- **CAD/OCR/Scanner:** `SKPConversionService`, OCR-/Scanner-Pipeline.
- **Hierarchie:** `HierarchieHelfer` (Bootstrap Event→Gebäude→Geschoss), `HierarchieMigration`.
- **Sonstiges:** `WetterService` + `BauWetterRegeln`, `NotificationService`,
  `Persistence` (Core-Data-Stack), mehrere Seeder für Demo-/Referenzprojekte.

---

## Wissensbasis (YAML)

`Service/ExactMatchKnowledge.swift` lädt beim Start alle YAMLs aus `Resources/Knowledge/`
(via Yams). **Vor jedem Mops-Call** wird per Alias-Match nachgeschaut — bei Treffer kommt
die Antwort sofort und offline, ohne LLM. Zwei Kategorien:

- **Fachwissen** — `din_normen.yaml`, `betongueten.yaml`, `moertelgruppen.yaml`,
  `wlg_werte.yaml` (DIN-Werte, Betongüten, Mörtelgruppen, Wärmeleitgruppen). UI: „📖 Aus Bau-Wissen".
- **App-Bedienung** — `app_bedienung.yaml` (Hilfetexte zur App selbst). UI: „🔧 Bedienungshilfe".

Jeder Eintrag hat `aliases` (längster Treffer gewinnt), `antwort`, `quelle_kurz`/`license_note`.
**Drift-Regel:** ändert ein PR die UI oder DIN-Werte, wird der passende YAML-Eintrag mitgezogen —
sonst „lügt" die Bedienungshilfe.

---

## Mops-Backend

Die KI-/Auswertungs-Funktionen sprechen mit **`mops-api`** — einem **separaten Repo**
(`AndreasPelczer/mops-api`, FastAPI/Python) auf einer CPU-Box im Heimnetz, öffentlich über
den Cloudflare-Tunnel **`https://mops.baumops.com`** (Default in der App, in den Settings
überschreibbar). CPU-only → großzügige Timeouts (bis 180 s).

| Endpoint | Zweck |
|---|---|
| `/health` | Verbindungs-Check |
| `/chat` | Fachfragen (lokales LLM); Prefix `/prof ` routet an Claude/OpenAI |
| `/classify` · `/classify-material` | Material-/KG-Klassifikation (BuildIQ) |
| `/extract-plan` | Plan-/LV-PDF → `ExtractPlanResult` (LV-Positionen + Bestellliste) |
| `/extract-doc` | Text-PDF → doctype-spezifische Fakten (`ExtractDocResult`) |
| `/gelaendebruecke/calculate` | DXF → Cut/Fill/Schotter/Vlies/LKW (`GelaendeResult`) |

> **Backend-Code gehört NICHT in dieses Repo** — hier lebt nur der iOS-Client. Der
> `server/`-Ordner *hier* ist ein separater Flask+Blender-Dienst (SKP/3D → USDZ), **nicht**
> der Mops.

---

## Kernel (Spike)

`Kernel/` (`TheBrain`, `KernelGuards`) ist ein **In-Memory-Spike**, 1:1 aus `iMOPS_OS_CORE`
übernommen — ein MUMPS-artiger Key-Value-Store, der **bewusst parallel zu Core Data ohne
Synchronisation** läuft, bei jedem App-Start neu geseedet wird und nichts persistiert. Dient
als eigene „Wahrheit" für experimentelle Domänen; bei Domänen-Arbeit an Core Data **nicht**
ungefragt mit echten Daten verdrahten.

---

## Build & Test

iOS-Deployment-Target **26.2**, Swift 5. Einzige externe Dependency: **Yams** (SPM).
Keine `.xcworkspace` — direkt das `.xcodeproj` bauen. **Pfade wegen des Trailing-Dots quoten.**

```bash
# Build (Simulator)
xcodebuild -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build

# Unit-Tests (nur das Unit-Target — sonst startet ein zweiter Simulator)
xcodebuild test -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Tests nutzen das **Swift-Testing-Framework** (`import Testing`, `@Test`, `#expect`), nicht
XCTest. CoreData-Tests bauen einen In-Memory-Stack über `PersistenceController(inMemory: true)`
und müssen den Controller **festhalten** (struct — sonst verlieren die Objekte ihre Attribute).

---

## Repo-Konventionen

**The Mops Protocol:**

- Keine direkten Pushes auf `main` (Hook-blockiert). Workflow: `feature/…` → Push → PR → Merge.
- **Conventional Commits** (`feat:` / `fix:` / `docs:` / `chore:` / `refactor:` / `test:`),
  gern mit Wellen-Referenz.
- **Drift-Regeln:** UI-Änderung → `Resources/Knowledge/app_bedienung.yaml` mitziehen;
  DIN/Fachwissen-Änderung → passende YAML ergänzen (Quelle + `license_note`, kein Norm-Volltext).
- Ein Feature ist erst fertig, wenn **Build grün und ein Test bestanden** ist — nicht, wenn
  jemand „ich denke, das läuft" sagt.
- `Secrets.plist` (enthält `GEMINI_API_KEY`) ist gitignored und wird nicht committet.

---

## Stand der Wellen & Roadmap

**Fertig (auf `main`):**

| Welle / Stufe | Feature |
|---|---|
| 5 | Aufmaß-Entity, Soll/Ist-Ampel, „gemessen verdrängt geschätzt" |
| 6 | Kalkulation (Live-Summe, EK), Kostenzusammenfassung, GAEB-X84, Stammdaten-Pflege |
| 7 | Geländebrücke (DXF → Cut/Fill/Schotter/Vlies/LKW, PDF-Report, LV-Brücke), flexible Layer-Erkennung |
| 9 | Hierarchie Gebäude/Geschoss (A sichtbar, B verwaltbar, C Ebenen-Freigabe) + Voraussetzungs-Ampel |
| Stufe 1 | Mehrfach-PDF-Upload im LV-Import |
| Stufe 2 | Dokumenten-Extraktion `/extract-doc` — Box-Route **und** iOS-Client („Unterlagen auswerten") |
| — | LV-Import aus JSON-Datei · KG-beim-Import-Heuristik · **Baustellen-Ist-Übersicht (Weg B)** inkl. Zeitplan/Bauphasen · Mac-Catalyst-Fixes |

**In Arbeit / geplant:**

- **Auswertungen speichern** — `/extract-doc`-Ergebnisse am Event persistieren + wieder
  aufrufen (+ Kern-Fakten im Ist-Übersicht-Kopf). Handoff geschrieben.
- **Vision-Fallback (C1Pdf)** im Backend — PDFs mit kaputtem Text-Layer (z. B. Town & Country /
  „ComponentOne C1Pdf") per Seiten-Render + Vision auswerten, statt an der Textextraktion zu
  scheitern. Spec + Codex-Auftrag liegen.
- **Geländebrücke:** `fix_okbp` (geplante Gründungssohle) im Backend verkabeln;
  Adresse→Automatik (Adresse → DGM → Cut/Fill).
- **Mops-Provider-Switch** (Claude-Guthaben) und weitere Stammdaten-Importe (XLSX/CSV).

---

## Dokumente & Übergaben

Specs, Handoffs und Protokolle liegen unter `docs/` — u. a. die Wellen-Specs, die
Baustellen-Übersicht-Spec, die Stufe-2-/Vision-Fallback-Specs, Codex-Aufträge und die
datierten Übergabe-/Einweisungs-Dokumente. Hinweis: ältere Roadmap-Dateien sind teils
veraltet — **der Code ist oft weiter als die Doku.**

---

*Bauleitung ist Handwerk. Diese App auch: erst messen, dann sägen.*
