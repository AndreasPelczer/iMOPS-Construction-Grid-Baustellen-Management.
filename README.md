# iMOPS — Construction Grid Baustellen-Management

iOS-App (Swift / SwiftUI) für das Baustellen- und Auftragsmanagement von Andreas Pelczer.
Offline-First mit Core Data, MVVM, keine externen Dependencies im Frontend.

> "Code lügt nicht, Fantasie schon. Wir bleiben am Boden der Tatsachen, der Commits und der echten Baustelle."

---

## Stand der Wellen (Stand 2026-07-03)

| Welle / Stufe | Feature | Status |
|-------|---------|--------|
| 5.1 | Aufmaß-Entity + Soll/Ist-Skelett | gemergt (PR #56) |
| 5.2 / 5.2.1 | AufmassSheet, Soll/Ist-Ampel, Fortschritt-Ableitung (gemessen verdrängt geschätzt) | gemergt (PR #58/#61) |
| 5.3 | BuildIQ: Menge erkennen (`/classify-material`) + Scan auf LV-Position buchen (Aufmaß, quelle=buildiq) | Buchung auf `codex/lv-baustein-search` (PR ausstehend) |
| 6 | Kalkulation (Live-Summe, EK), Kostenzusammenfassung, GAEB-X84→AngebotsStore | gemergt (PR #68); **Stammdaten-Pflege** (Löhne/Material/Geräte) auf Branch (PR ausstehend) |
| 7 | Geländebrücke — DXF-Upload, IDW/Cut-Fill, Schotter/Vlies/LKW, PDF-Report, Brücke ins LV | gemergt (PR #67); Massen jetzt als `mengenQuelle=schaetzung` gekennzeichnet (Branch) |
| 9 | Voraussetzungs-Ampel (Rot/Grün baufrei) + Hierarchie Gebäude/Geschoss | MVP gemergt (PR #73–75); Ausbau offen |
| Stufe 1 | Mehrfach-PDF-Upload im LV-Import | auf Branch (PR ausstehend) |
| Stufe 2 | Dokumenten-Extraktion (Text-PDF → strukturierte Felder, `/extract-doc`) | Box-Route live; iOS-Client offen (Spec) |

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
- Host: Mops-Box (Ubuntu, CPU-only) im Heimnetz, erreichbar über Tunnel https://mops.baumops.com (Default in der App, in Settings änderbar)
- Endpoints u. a.: /chat, /prof (→ Claude/OpenAI, umschaltbar), /classify, /classify-material (BuildIQ, Welle 5.3), /health, /extract-plan, /extract-doc (Stufe 2), /gelaendebruecke/calculate (Welle 7)

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

## Roadmap (Stand 2026-07-03)

- **Welle 9 — Voraussetzungs-Ampel:** MVP gemergt (Hierarchie Gebäude/Geschoss, AmpelCard in EventDetailView). Ausbau offen: Voraussetzungs-Katalog, ReadinessManager-Rollup, Polier-Freigabe. Profitiert davon, dass Geländebrücke- und Import-Mengen als `mengenQuelle=schaetzung` gekennzeichnet sind.
- **Welle 6 Rest:** XLSX-Import für Stammdaten, Mittellohn-Aggregat.
- **Welle 7 — Adresse→Automatik:** neuer Box-Endpoint (Adresse→DGM1→Cut/Fill) + Adressfeld/Auto-Aufruf in der App. Spec: docs/Welle7-Adresse-Automatik.md.
- **Stufe 2 — iOS-Client:** `/extract-doc` anbinden (Multi-Picker + Review-Liste). Spec: docs/Stufe2-Dokumenten-Extraktion.md.
- Hinweis: docs/roadmap_wellen_5_bis_9.md ist teils veraltet — der Code ist oft weiter als die Roadmap.

---

## Übergaben und Protokolle

- docs/uebergabe_04_06_2026.md
- docs/uebergabe_05_06_2026.md
- docs/uebergabe_09_06_2026.md
- docs/uebergabe_19_06_2026.md — Welle 7 abgeschlossen, Welle 6 MVP, Welle 9 als nächstes
- docs/HANDOFF-2026-07-03.md — Stufe 1 (Multi-Upload), Stufe 2 (Doku-Extraktion), Geländebrücke-Fix, Box-Runbook
