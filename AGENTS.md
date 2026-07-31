# AGENTS.md

This file provides guidance to Codex (codex.ai/code) when working with code in this repository.

Inhaltsgleich mit CLAUDE.md — bei Aenderungen BEIDE Dateien nachziehen.

## 🚧 ERST HIER LESEN — Pflichtspur für jede neue Instanz

**Bevor du irgendetwas analysierst, vorschlägst oder änderst:**
1. `git status` + `git branch -a` — wo stehst du, welche offenen Branches gibt es? (Oft läuft schon Arbeit am selben Thema.)
2. **`docs/HANDOFF-AKTUELL.md`** lesen — der stabile Zeiger auf den aktuellen Stand. Nicht die Datumssuche raten.
3. Bevor du etwas Neues entwirfst: `rg <begriff>` in Code **und** `docs/`. **Das Feature existiert wahrscheinlich schon** (View, Service, Branch, Handoff, Spec) — der Job ist meist *verbinden/reparieren*, nicht neu erfinden.
4. Zweites Repo mitdenken: iOS-Client ↔ **mops-api** (Box-Backend). Ein Handoff betrifft oft beide.

Erst wenn diese vier Punkte durch sind, Vorschläge machen. **Warum:** jeder Mac-Neustart = frische Instanz ohne Erinnerung an gestern. Das Repo + `docs/` SIND die Kontinuität, die die Instanz selbst nicht hat.

**⏹ Am Session-Ende (Pflicht):** `docs/HANDOFF-AKTUELL.md` auf einen Satz bringen — was ist *jetzt* der Stand, was offen? Sonst lügt der Zeiger die nächste Instanz an. Das ist der wichtigste Schritt der ganzen Spur.

## Was das ist

SwiftUI/Core-Data iOS-App für Baustellen- und Auftragsmanagement (Bauleitung).
Solo-Projekt. Entstanden aus einer Gastro-/Catering-App (GASTRO-GRID) und wird
schrittweise auf die Bau-Domäne umgebaut (siehe `PLAN.md`).

## ⚠️ Trailing-Dot im Namen

Der Projekt-Ordner, das `.xcodeproj` **und das Scheme** enden buchstäblich auf einen
Punkt: `iMOPS-Construction-Grid-Baustellen-Management.`. Das ist kein Tippfehler.
- Pfade in der Shell daher immer quoten.
- Der Swift-Modulname ist `iMOPS_Construction_Grid_Baustellen_Management_` (Punkt → `_`),
  relevant für `@testable import`.

## Build / Test

iOS-Deployment-Target **26.2**, Swift 5.0. Einzige externe Dependency: **Yams** (YAML, via SPM).
Es gibt keine `.xcworkspace` — direkt das `.xcodeproj` bauen.

```bash
# Build (Simulator)
xcodebuild -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Alle Tests
xcodebuild test -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Einzelner Test (Swift Testing → -only-testing mit Test-ID)
xcodebuild test ... -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests/iMOPS_Construction_Grid_Baustellen_ManagementTests/appLaunches"
```

Tests nutzen das **Swift-Testing-Framework** (`import Testing`, `@Test`, `#expect`),
nicht XCTest.

### Tests laufen lassen

Empfohlener Befehl für die Unit-Tests — gezielt nur das Unit-Target:

```bash
xcodebuild test -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Ohne `-only-testing`** zieht das Scheme zusätzlich das **UITests-Target** hoch — das
startet einen **zweiten Simulator** (langsamer, und bei wenig freier Platte häufig
`No space left on device` → SpringBoard-/Simulator-Crash). Für reine Logik-Tests also
immer `-only-testing` auf `…Tests` setzen.

CoreData-Tests bauen ihren In-Memory-Stack über `PersistenceController(inMemory: true)`,
müssen den Controller aber **festhalten** (struct — inline erzeugt wird der Container
sofort wieder freigegeben, Objekte verlieren dann ihre Attribute).

## Architektur

MVVM. Quellbaum liegt unter `iMOPS-Construction-Grid-Baustellen-Management./`:

- **App/** — Entry-Point (`iMOPSApp`), `AppSession` (Rolle: worker/dispatcher/director,
  steuert sichtbare Tabs in `RootTabView`), `Constants` (lädt `GEMINI_API_KEY` aus `Secrets.plist`).
- **Models/** — Core-Data-Entities. Das Datenmodell heißt aus Altlast-Gründen noch
  `test25B.xcdatamodeld`. Achtung: Catering-Reste (`CDProduct` mit Nährwerten/Allergenen,
  `CDIngredient`) existieren noch — werden laut `PLAN.md` durch Bau-Material-Modelle ersetzt.
- **Views/** + **ViewModels/** — SwiftUI-Views und ihre VMs.
- **Service/** — Geschäftslogik: GAEB-Import/-Export, LV-Kalkulation (Leistungsverzeichnis),
  DIN-276-Kostengruppen, Mangel-Verwaltung, Bautagesbericht, XRechnung-Export, Wetter-Regeln,
  Seeder, PDF-Export, OCR/Scanner, CAD-Import.
- **Kernel/** — siehe unten.
- **Resources/Knowledge/** — YAML-Wissensbasis, siehe unten.

### Mops-Backend (eigenes Repo)

Die App spricht mit einem lokalen LLM-Server (`AndreasPelczer/mops-api`, Default
`https://mops.baumops.com` — dauerhafter Cloudflare-Tunnel zur Mops-Box, in Settings
konfigurierbar). `MopsClient` ruft `/chat`,
`/classify`, `/health`; CPU-only, daher Timeout 180s. Prefix `/prof ` in einer Frage
routet serverseitig an Claude. **Backend-Code gehört NICHT hierher** — dieses Repo ist
nur der iOS-Client.

Verwechslungsgefahr: der `server/`-Ordner *hier* ist ein separater Flask+Blender-Dienst,
der SKP/3D-Dateien zu USDZ konvertiert — nicht der Mops-Server. `scripts/*.py` sind das
zugehörige Konvertierungs-Tooling (Blender headless).

### ExactMatchKnowledge (Pre-Filter)

`Service/ExactMatchKnowledge.swift` lädt beim Start alle YAMLs aus `Resources/Knowledge/`
(via Yams). **Vor jedem `MopsClient`-Call** wird hier per Alias-Match nachgeschaut — bei
Treffer kommt die lokale Antwort sofort (offline, kein LLM). Zwei Kategorien:
`fachwissen` (DIN-Werte, Beton, WLG, Mörtel → UI "📖 Aus Bau-Wissen") und `app-bedienung`
(Hilfetexte zur App selbst → UI "🔧 Bedienungshilfe"). Lizenz-Regel: **kein DIN-Norm-Wortlaut**
in `antwort:` kopieren, nur Werte/Sachverhalte.

### Kernel/ (Spike — Vorsicht)

`TheBrain` + `KernelGuards` sind ein **In-Memory-Spike**, 1:1 kopiert aus `iMOPS_OS_CORE`.
- TheBrain ist ein MUMPS-artiger globaler Key-Value-Store (`^TASK.<id>.STATUS` etc.) mit
  thread-safe Queue, der einen "Meier-Score" (Pelczer-Matrix) berechnet.
- **Läuft bewusst parallel zu Core Data, ohne Synchronisation.** Wird bei jedem App-Start
  neu geseedet (`TheBrain.shared.seed()`), nichts wird persistiert.
- KernelGuards = ethischer/Privacy-Layer (Anonymisierung, Fatigue-Schutz "BourdainGuard").
- Bei Domänen-Arbeit an Core Data diesen Kernel nicht mit echten Daten verdrahten, ohne
  das explizit zu klären — er ist eine eigene "Wahrheit" für neue Domänen.

## Repo-Konventionen (aus CONTRIBUTING.md)

- Branches: `feature/…`, `fix/…`, `chore/…`. Alles außer Mikro-Fixes über PR, nicht direkt `main`.
- Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
- Domain-Begriffe deutsch im Code (`bauherr`, `kostenGruppe`), sonst englisch. iOS 17+, kein neuer UIKit-Mix.
- **Drift-Regeln (wichtig):**
  - PR ändert UI (neuer Button, umbenannter Tab, Workflow) → passenden Eintrag in
    `Resources/Knowledge/app_bedienung.yaml` mitziehen. Sonst lügt die Bedienungshilfe.
  - PR ändert DIN/Fachwissen → passende YAML ergänzen, `quelle_kurz`+`license_note` ausfüllen,
    kein Norm-Volltext.

## Secrets

`Secrets.plist` ist gitignored und enthält `GEMINI_API_KEY`. Nicht committen.
