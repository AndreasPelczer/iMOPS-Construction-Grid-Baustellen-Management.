# Phase 2a Setup — Kernel-Spike (iMOPS_OS_CORE)

Dieser PR bringt einen **Spike** des iMOPS_OS_CORE Kernels in die App.
Architektur-Entscheidung (Andreas + Codi, 01.06.2026):

- **Variante 1c (Integration):** Copy-In — drei Kernel-Files direkt im Repo,
  später ggf. Migration zu SPM-Package wenn iMOPS_OS_CORE Library-fähig wird
- **Variante 2a (Erstes Modul):** BourdainGuard für Crew-Schichten im
  CrewPlanningView-Tab
- **Variante 3b (Datenhoheit):** Kernel als NEUE Wahrheit für neue Domänen.
  Keine Synchronisation mit CoreData — TheBrain läuft parallel,
  in-memory only, kein Sync-Drama

## Was du in Xcode tun musst (~2 Minuten)

### 1. Kernel-Ordner als Group hinzufügen

Die drei Kernel-Files liegen unter `iMOPS-Construction-Grid-Baustellen-Management./Kernel/`:
- `TheBrain.swift` — MUMPS-Style In-Memory Store + Pelczer-Matrix
- `KernelGuards.swift` — SecurityLevel + MenschMeierModus + BourdainGuard
- `KernelArbeitsschritt.swift` — Typisiertes Task-Modell

**In Xcode:**
- Im Project Navigator: Rechtsklick auf den App-Hauptordner
  `iMOPS-Construction-Grid-Baustellen-Management.` (gelber Ordner)
- **Add Files to "iMOPS-Construction-Grid-Baustellen-Management."**
- Den `Kernel`-Ordner auswählen
- Im Dialog:
  - **Action:** "Reference files in place" (NICHT "Copy files to destination")
  - **Targets:** iMOPS-Construction-Grid-Baustellen-Management. ankreuzen
- **Finish**

**Verifikation:** Im Project Navigator erscheint `Kernel` als **gelbe Group**
(Code-Files brauchen Group, nicht Folder Reference — anders als die YAMLs!),
darunter die 3 Swift-Files.

### 2. Build (Cmd+B)

Sollte grün durchlaufen. Falls rote Linien:

| Fehler | Wahrscheinliche Ursache |
|--------|------------------------|
| `Cannot find 'TheBrain' in scope` | Files nicht im Target-Membership. Im File-Inspector rechts unter "Target Membership" haken setzen. |
| `Type 'TheBrain' has no member 'shared'` | iOS-Version-Issue. Target muss iOS 17+ sein (sollte schon stimmen). |
| `Cannot find 'KernelGuardStatusView' in scope` | View ist unter `Views/`, sollte automatisch gefunden werden. Cmd+Shift+K + Cmd+B. |

### 3. App im Simulator starten

- Crew-Tab öffnen
- **Erwartung:** Oben in der Liste erscheint ein **Kernel-Status-Banner**:
  - Header "Crew-Schutz" mit Herz-Icon (grün = fresh, da Schicht gerade gestartet)
  - Brigade-Last 0% (keine offenen Tasks außer dem Demo-Gerüst)
  - "Fresh" Label
- Keine Whisper-Message (Schicht ist neu)

**In der Xcode-Konsole** sollten diese Zeilen erscheinen:
```
iMOPS-KERNEL: Seed abgeschlossen. Matrix-Score: <N>
iMOPS-KERNEL: Branche: BAUSTELLE
```

## Was macht der Spike?

**TheBrain.shared.seed()** beim App-Start in `iMOPSApp.swift`:
- Lädt Demo-Brigade (Stefan K. + Timo R.) in den Kernel
- Legt einen Demo-Task an (Gerüstprüfung)
- Setzt `^SYS.SHIFT_START` auf jetzt
- Initialisiert SecurityLevel auf "standard"

**KernelGuardStatusView** in `CrewPlanningView`:
- Alle 60 Sekunden: `KernelGuards.evaluate()` aufrufen
- Zeigt:
  - SecurityLevel-Icon (shield)
  - FatigueLevel-Icon (heart / warning / bolt-heart)
  - Brigade-Last (0-100% Progress-Bar)
  - Whisper-Message bei 8h / 10h Schicht
  - Indikatoren für Training-Mode + Privacy-Shield

## Spike-Beschränkungen (bewusst, für Phase 2b zu lösen)

1. **In-Memory:** TheBrain hat keinen Persistence-Layer. Bei App-Restart sind
   alle Daten weg. Der `seed()` bei jedem Start ist Workaround.
2. **Demo-Brigade:** Stefan/Timo sind hartcodiert. Phase 2b müsste die echten
   `Employee`-CoreData-Objekte in den Kernel spiegeln.
3. **Demo-Task:** Das "GERÜSTPRÜFUNG"-Task ist nur für die Matrix-Berechnung
   da. Phase 2b: echte Auftrags-Statusse als Tasks tracken.
4. **Schicht-Start = App-Start:** Aktuell wird `^SYS.SHIFT_START` beim ersten
   `seed()` gesetzt. Für die echte Welt: `TheBrain.shared.startNewShift()`
   manuell triggern (Button "Neue Schicht").

## Was als nächstes (Phase 2b)

Wenn der Spike sich bewährt — also der GuardReport beim Bauleiter Aha-Effekte
auslöst — ist die natürliche Fortsetzung:

| Ausbau | Aufwand | Was es bringt |
|--------|---------|---------------|
| Echte Mitarbeiter → Brigade | ~2 h | Stefan/Timo raus, CoreData-Employees in den Kernel spiegeln |
| Auftrag-Status → Tasks | ~3 h | Open Auftrag → ^TASK.xxx im Kernel, automatische Matrix-Last |
| Persistenz für ^ARCHIVE | ~4 h | UserDefaults oder eigenes File für ^ARCHIVE.*-Schlüssel (HACCP-Snapshots überleben App-Restart) |
| Self-Check als Settings-Section | ~1 h | kernelSelfCheck() in Settings aufrufen, 13 Tests anzeigen |
| Export-Methoden (CSV/JSON/Text) | ~2 h | aus dem Original TheBrain.swift mitziehen, Settings-Button "Audit-Export" |
