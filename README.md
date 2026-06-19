# iMOPS — Construction Grid Baustellen-Management

iOS-App (Swift / SwiftUI) für das Baustellen- und Auftragsmanagement von Andreas Pelczer.
Offline-First mit Core Data, MVVM, keine externen Dependencies im Frontend.

> "Code lügt nicht, Fantasie schon. Wir bleiben am Boden der Tatsachen, der Commits und der echten Baustelle."

---

## Stand der Wellen

| Welle | Feature | Status |
|-------|---------|--------|
| 5.1 | Aufmaß-Entity + Soll/Ist-Skelett | erledigt, gemergt (PR #56) |
| 5.2 | AufmassSheet + Soll/Ist-Karte | erledigt, gemergt (PR #58) |
| 5.2.1 | Fortschritt-Ableitung — gemessen verdrängt geschätzt | erledigt, gemergt (PR #61) |
| 6 | Kalkulation — LVKalkulationView mit Live-Summe und Einkaufspreisen | erledigt, gemergt (PR #68) |
| 7 | Geländebrücke — DXF-Upload, IDW-Interpolation, Cut/Fill, PDF-Report, Brücke ins LV | erledigt, gemergt (PR #67) |
| 9 | Voraussetzungs-Ampel (Rot/Grün Baufrei) | geplant — Fundament mengenQuelleRaw liegt (PR #54) |

---

## Architektur

~~~
iMOPS-Construction-Grid-Baustellen-Management./
├── App/                  App-Einstieg, Szenen-Konfiguration
├── Models/               Core-Data-Entities + Subclasses
│   ├── test25B.xcdatamodeld
│   ├── LVPosition+CoreDataClass.swift
│   ├── Aufmass+CoreDataClass.swift      Welle 5.1
│   └── GelaendeResult.swift             Welle 7
├── Views/                SwiftUI-Views (~50 Dateien)
│   ├── EventDetailView.swift            Hub: DXF-Upload (Welle 7), Kalkulation (Welle 6)
│   ├── LVKalkulationView.swift          Welle 6
│   ├── CADImportView.swift / CADViewerView.swift   Welle 7
│   ├── AufmassSheet.swift               Welle 5.2
│   └── ...
├── ViewModels/           MVVM (AddJob, BauWissen, EventList, Job*)
├── Service/              Domänen-Services und Exporter
│   ├── LVKalkulator.swift               Welle 6
│   ├── MopsKalkulationsHelper.swift     Welle 6
│   ├── ExtractPlanMapper.swift          persistiert mengenQuelleRaw (Welle-9-Basis)
│   ├── HouseProject/Generator.swift     Welle 7
│   └── Exporter (GAEB, LVPDF, LVCSV, MangelPDF, BautagesberichtPDF, XRechnung)
├── Kernel/               Guard-/Workflow-Engine (TheBrain, KernelGuards)
└── Resources/
~~~

Datenhaltung: Core Data, Offline-First. Core-Data-Model: test25B.xcdatamodeld.

---

## Backend (separates Repo)

Frontend kommuniziert mit dem lokalen Python-Backend mops-api:
- Repo: AndreasPelczer/mops-api
- Stack: FastAPI / Python
- Host: Mops-Box 192.168.2.42:8080 (Ubuntu, CPU-only)
- Endpoints u. a.: /chat, /classify, /health, /admin-ui, /prof, /gelaendebruecke/calculate (Welle 7)

---

## Setup

1. Xcode öffnen, Projekt clonen.
2. Core-Data-Model test25B.xcdatamodeld liegt bei, keine Migration nötig für aktuellen main.
3. Build und Run im Simulator oder auf dem Gerät.
4. Für Welle 7 (Geländebrücke): Mops-Box im gleichen Netz wie in den App-Einstellungen konfiguriert.

Keine externen Dependencies via SPM nötig.

---

## Git-Disziplin (The Mops Protocol)

- Keine direkten Pushes auf main (Hook-blockiert).
- Workflow: feature/... -> Push -> PR -> Review -> Merge.
- Commit-Style: feat: / fix: / docs: / chore: mit Wellen-Referenz.
- Ein Feature ist erst fertig, wenn Build grün und ein Test bestanden ist — nicht wenn jemand "ich denke, das funktioniert" sagt.

---

## Roadmap

Welle 9 — Voraussetzungs-Ampel (nächster Sprint):
- [GRÜN] Fundament liegt: LVPosition.mengenQuelleRaw (gemessen/geschätzt) bereits in Core Data + Import (PR #54).
- [GELB] Zu bauen: Hierarchie (Gebäude/Geschoss), ReadinessManager-Rollup, Voraussetzungs-Katalog, AmpelCard-UI, Polier-Freigabe.
- Siehe docs/roadmap_wellen_5_bis_9.md.

---

## Übergaben und Protokolle

- docs/uebergabe_04_06_2026.md
- docs/uebergabe_05_06_2026.md
- docs/uebergabe_09_06_2026.md
- docs/uebergabe_19_06_2026.md — Welle 7 abgeschlossen, Welle 6 MVP, Welle 9 als nächstes
