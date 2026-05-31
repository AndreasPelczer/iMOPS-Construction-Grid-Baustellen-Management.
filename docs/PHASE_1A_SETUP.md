# Phase 1a Setup — ExactMatchKnowledge

Setup-Schritte für die iOS-side Pre-Filter-Schicht. **Einmal nach Pull
ausführen, dann läuft alles automatisch.**

## Was du in Xcode tun musst (~3 Minuten)

### 1. Yams Package hinzufügen (~1 Minute)

In Xcode:
- Menü: **File → Add Package Dependencies…**
- URL einfügen: `https://github.com/jpsim/Yams.git`
- Dependency Rule: **Up to Next Major Version** ab `5.0.0`
- Add to Target: **iMOPS-Construction-Grid-Baustellen-Management.**
- Klick auf **Add Package**

Verifikation: in `ExactMatchKnowledge.swift` sollte `import Yams` kompilieren
ohne roten Strich.

### 2. Knowledge-Folder als Bundle-Resource registrieren (~1 Minute)

Die YAML-Dateien müssen ins App-Bundle kopiert werden. Aktuell liegen sie
unter `iMOPS-Construction-Grid-Baustellen-Management./Resources/Knowledge/`.

In Xcode:
- Im Project Navigator das **iMOPS-Construction-Grid-Baustellen-Management.**
  Target wählen
- Tab **Build Phases → Copy Bundle Resources**
- Klick auf **+** unten
- Wenn `Resources/Knowledge` schon als Folder Reference im Projekt ist:
  einfach das Verzeichnis hinzufügen
- Wenn nicht: **File → Add Files to…**, dann `Resources/Knowledge` wählen,
  bei **Reference type** unbedingt **Create folder references** (blauer
  Ordner-Icon) — NICHT "Create groups". Sonst werden die YAMLs nicht
  rekursiv mit aufgenommen.

Verifikation: nach Build sollte unter `Products → iMOPS.app → Resources →
Knowledge/` die vier YAMLs liegen.

### 3. Build + Test (~30 Sekunden)

- **Cmd+B** Build
- Wenn grün: in der App `BauWissenView` öffnen (kommt in Phase 1b mit
  ExactMatch-Integration)
- Vorher: schneller Diagnose-Test in `iMOPSApp.swift` einbauen:

```swift
.task {
    let count = await ExactMatchKnowledge.shared.entryCount()
    print("Knowledge entries loaded: \(count)")  // sollte 22 sein
}
```

`22` = 10 DIN-Einträge + 5 Beton + 4 WLG + 4 Mörtel + 1 Expositionsklassen-Gruppe.
Wenn da `0` steht: Bundle-Resource-Setup hat nicht geklappt, Schritt 2 prüfen.

## Was als nächstes kommt (Phase 1b)

Nach diesem Setup integriert sich Phase 1b in `BauWissenView`:
- Vor jedem `mopsClient.ask(...)` ein `await ExactMatchKnowledge.shared.lookup(question)`
- Bei Hit: Antwort direkt anzeigen mit Source-Card "Aus iMOPS-Wissensbasis"
- Bei Miss: weiter wie bisher zum Mops-Server

Den Code für Phase 1b mache ich danach in einem zweiten PR.

## Troubleshooting

**`import Yams` zeigt rote Linie:** Schritt 1 prüfen, Xcode neustarten (manchmal
muss SPM den Cache neu laden).

**`entryCount()` gibt 0 zurück:** Schritt 2 prüfen. Im Build-Log nach "Knowledge"
suchen — wenn die YAMLs nicht im "Copy Bundle Resources" Phase auftauchen,
sind sie nicht im Bundle.

**`bundle.url(forResource:)` findet die YAML nicht:** Folder-Reference vs Group?
Der Code fällt zurück auf "ohne subdirectory" als Plan B, aber sauberer ist
Folder Reference. Wenn alles fehlschlägt: YAMLs ins Root-Resources verschieben
und `subdirectory:` aus dem Code entfernen.
