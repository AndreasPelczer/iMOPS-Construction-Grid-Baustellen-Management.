# Einweisung — iMOPS Construction-Grid (Stand 2026-07-04, Vormittag)

Onboarding für einen Kollegen: was heute geändert wurde und wie du reinkommst.
Präsentations-Version (druckbar als PDF): siehe Artifact-Link, den Andreas teilt.

## 1. Zugang — wie du rankommst
- **GitHub:** `github.com/AndreasPelczer/iMOPS-Construction-Grid-Baustellen-Management.`
- **Lokal (kanonisch):** `~/XcodeProjects/iMOPS-Construction-Grid-Baustellen-Management.` — **nur diese Kopie benutzen.** Eine verwaiste Zweitkopie in `~/Documents` wurde heute aufgeräumt.
- **Branch:** alles auf `main` (heute via PR #85 + #86 gemergt). `git pull`.
- **⚠️ Trailing-Dot:** Ordner, `.xcodeproj` und Scheme enden buchstäblich auf einen **Punkt** — Pfade in der Shell quoten. Modulname für `@testable import`: `iMOPS_Construction_Grid_Baustellen_Management_`.
- **Dependencies:** keine außer **Yams** (SPM). Kein Workspace — direkt das `.xcodeproj`.

```bash
# Bauen (Simulator-Ziel: iPhone 17 Pro Max)
xcodebuild -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build

# Tests (nur Unit-Target — sonst startet ein 2. Simulator)
xcodebuild test ... -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests/HierarchieTests"
```

## 2. Was wir heute gemacht haben

**a) Repo-Konsolidierung (PR #85)** — zwei divergierte Kopien zusammengeführt, verwaiste
Kopie + Streuordner entsorgt. Aus der alten Kopie gerettet: Ampel-Button-Fix in
`EventDetailView` (kaputter Button-im-Button → Ampel-Klick öffnet direkt die
Kausalbaukette) und Aufträge nach DIN-276-Kostengruppe gruppiert.

**b) Welle 9 — Bau-Hierarchie A+B+C (PR #86).** Die Hierarchie
`Event → Gebäude → Geschoss → LVPosition` war im Modell verdrahtet + per Migration
befüllt, aber **inert** (kein View las sie). Jetzt lebendig:
- **A — sichtbar:** getypte Accessoren (`LVPosition.geschoss`); `HierarchieHelfer`
  (Default-Geschoss nie nil, self-healing); 3. LV-Achse „Ebene" + „Kosten nach Ebene".
- **B — verwaltbar:** Geschoss-Picker beim Position-Anlegen; „Ebenen verwalten"
  (Gebäude/Geschosse anlegen, umbenennen, sortieren, löschen).
- **C — freigebbar:** Freigabe pro Geschoss + Voraussetzungs-Katalog (5 manuell + 2
  automatisch-live); Gebäude grün, wenn alle Geschosse frei. **Reine Anzeige, kein Gate.**

**In der App:** LV-Ansicht → Segment-Umschalter oben (Achse „Ebene") und das
⋯-Menü („Kosten nach Ebene", „Ebenen verwalten", „Ebenen-Freigabe / Status").

## 3. Neue / geänderte Dateien
**Neu:** `Service/HierarchieHelfer.swift`, `Models/Hierarchie+Status.swift`,
`Models/Voraussetzung+CoreDataClass.swift`, `Views/GeschossKostenView.swift`,
`Views/HierarchieVerwaltenView.swift`, `Views/FreigabeStatusView.swift`,
`Tests/HierarchieTests.swift`.

**Geändert:** `Models/test25B.xcdatamodeld` (+ Entity `Voraussetzung`, Geschoss-Felder),
`Geschoss/LVPosition/Event+CoreDataProperties`, `HierarchieMigration.swift`,
`Views/LVView.swift`, `Views/LV/AddLVPositionView.swift`, `Views/EventDetailView.swift`,
`Resources/Knowledge/app_bedienung.yaml`.

**Pflichtlektüre für Welle 9:** `docs/Welle9-Hierarchie-Karte-und-Spec.md` — Karte + §0–§7-Bau-Checkliste.

## 4. Konventionen & Fallen
- **Backup vor jedem Patch** (`.backup_*`). **Kein Push / kein PR ohne Andreas' ausdrückliches OK.**
- **Core-Data-Entities von Hand** (Codegen Manual/None; `@objc(Name)` + Klassendatei selbst — sonst Laufzeit-`unrecognized selector`).
- **`.xcdatamodeld`-Backup nicht in `Models/`** ablegen (Xcode kompiliert es sonst als 2. Modell) → Repo-Wurzel.
- Modell-Änderung: neue Bool-Felder mit **Default + non-optional**, Rest optional → sonst bricht die Lightweight-Migration. Danach sofort einmal bauen.
- **SourceKit-Meldungen im Editor ("Cannot find type …") ignorieren** — Whole-Module-Artefakte; **maßgeblich ist `xcodebuild`**.
- Drift-Regel: UI-Änderung → Eintrag in `app_bedienung.yaml` mitziehen. Deutsch im Code für Domänen-Begriffe; Conventional Commits.

## 5. Koordination (wichtig!)
Ein zweiter Assistent („**Codi**") arbeitet parallel am **selben Branch/Working-Tree**.
**Vor dem Loslegen abstimmen, wer dran ist** — sonst überschreibt ihr euch oder es gibt
Push-Konflikte. Codis Planungs-Docs liegen teils untracked im Working-Tree — nicht
mit-committen, wenn's nicht deins ist.
