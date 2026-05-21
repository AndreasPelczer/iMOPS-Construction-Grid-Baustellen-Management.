# 🎨 iMOPS SketchUp-Plugin - UI Mockup

## Übersicht

Dieses Dokument zeigt, wie das SketchUp-Plugin aus Sicht des Users (Raphael) aussieht.

---

## 1️⃣ Plugin-Installation (einmalig)

### Schritt 1: Extension Manager öffnen

```
SketchUp Menü:
Window → Extension Manager → Install Extension

→ Datei auswählen: iMOPS_Construction_Grid.rbz
→ "Ja" bei Sicherheitsabfrage klicken
→ SketchUp neu starten
```

### Schritt 2: Plugin erscheint im Menü

```
Neuer Menüpunkt in SketchUp:

┌────────────────────────────────┐
│ File  Edit  View  Camera  Draw │
│ Tools  Window  Extensions      │
│                                │
│ ▼ Extensions                   │
│   ├─ Extension Manager         │
│   ├─ Extension Warehouse       │
│   ├─ ...                       │
│   └─ 🏗️ iMOPS Construction Grid│  ← NEU!
│       ├─ Export für iMOPS      │
│       ├─ Einstellungen         │
│       └─ Hilfe                 │
└────────────────────────────────┘
```

---

## 2️⃣ Hauptfenster: Export-Dialog

### Wenn User auf "Extensions → iMOPS → Export für iMOPS" klickt:

```
╔═══════════════════════════════════════════════════════════════╗
║  iMOPS Construction Grid - Export                             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📁 Projekt-Informationen                                     ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Projekt-Name:  [Mannheim Gewerbepark              ]          ║
║                                                               ║
║  Bauherr:       [Müller GmbH                       ]          ║
║                                                               ║
║  Standort:      [Mannheim, Industriestraße 42      ]          ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📤 Export-Optionen                                           ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Was soll exportiert werden?                                  ║
║                                                               ║
║  ☑ Sicherheits-Daten (Gefahrenzonen, PSA, Compliance)        ║
║  ☑ Kalkulations-Daten (Bauteile, Kosten, LV)                 ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ⚙️ Erweiterte Einstellungen                                  ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Erkenne automatisch:                                         ║
║  ☑ Absturz-Gefahren (Höhe > 2m)                               ║
║  ☑ Enge Räume (Fläche < 15m²)                                 ║
║  ☑ Maschinen-Sicherheitsabstände                              ║
║  ☑ Bauteile für Kalkulation                                   ║
║                                                               ║
║  Einheiten:                                                   ║
║  ⦿ Meter (m, m², m³)                                          ║
║  ○ Feet (ft, sq.ft)                                           ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📊 Modell-Übersicht (wird beim Scan ausgefüllt)              ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Gefundene Objekte:                                           ║
║  • Gruppen/Zonen:        [?] (noch nicht analysiert)          ║
║  • Komponenten:          [?]                                  ║
║  • Flächen (Wände):      [?]                                  ║
║  • Gefahrenzonen:        [?]                                  ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  [🔍 Modell vorab scannen]   [❌ Abbrechen]   [✅ Export]     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 3️⃣ Vorab-Scan: Modell analysieren

### Wenn User auf "🔍 Modell vorab scannen" klickt:

```
╔═══════════════════════════════════════════════════════════════╗
║  Scanne SketchUp-Modell...                                    ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ████████████████████░░░░░░░░░░  65%                          ║
║                                                               ║
║  Aktuell: Analysiere Gruppe "Dachgeschoss"...                 ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ✅ Gruppen analysiert:       12                              ║
║  ✅ Komponenten gefunden:     47                              ║
║  ✅ Flächen berechnet:        156                             ║
║  ⏳ Gefahrenzonen erkannt:    [läuft...]                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Nach dem Scan:

```
╔═══════════════════════════════════════════════════════════════╗
║  iMOPS Construction Grid - Export                             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📊 Scan-Ergebnis                                             ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ✅ Modell erfolgreich analysiert!                            ║
║                                                               ║
║  Gefundene Objekte:                                           ║
║  • Gruppen/Zonen:        12                                   ║
║  • Komponenten:          47                                   ║
║  • Flächen (Wände):      156 (1.245 m²)                       ║
║  • Gefahrenzonen:        5                                    ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  🚨 Erkannte Gefahrenzonen:                                   ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ⚠️  "Dachgeschoss"                                           ║
║      → Höhe: 12.5m (> 2m) → ABSTURZ-GEFAHR                    ║
║      → Empfohlene PSA: Helm, Absturzsicherung                 ║
║      → Status: ☑ Als Gefahrenzone markieren                   ║
║                                                               ║
║  ⚠️  "Kellerraum 3"                                           ║
║      → Fläche: 8.5m² (< 15m²) → ENGER RAUM                    ║
║      → Empfohlene PSA: Atemschutz, Sauerstoffmessgerät        ║
║      → Status: ☑ Als Gefahrenzone markieren                   ║
║                                                               ║
║  ⚠️  "Staplerweg Außen"                                       ║
║      → Komponente: "Gabelstapler" gefunden                    ║
║      → Typ: FAHRZEUGVERKEHR                                   ║
║      → Status: ☑ Als Gefahrenzone markieren                   ║
║                                                               ║
║  ⚠️  "Kranbereich"                                            ║
║      → Komponente: "Turmdrehkran TK60"                        ║
║      → Sicherheitsabstand: 10m empfohlen                      ║
║      → Status: ☑ Als Gefahrenzone markieren                   ║
║                                                               ║
║  ⚠️  "Schweißbereich"                                         ║
║      → Tag: "Elektrik" + Name enthält "Schweiß"               ║
║      → Typ: BRANDGEFAHR / FUNKENFLUG                          ║
║      → Status: ☑ Als Gefahrenzone markieren                   ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  💰 Kalkulations-Daten:                                       ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Bauteile für LV:                                             ║
║  • Trockenbau-Wände:     45.5 m²  → ~1.297 EUR                ║
║  • Beton-Böden:          120.0 m² → ~10.200 EUR               ║
║  • Türen (90x210):       5 Stück  → ~2.250 EUR                ║
║  • Fenster (120x150):    12 Stück → ~4.800 EUR                ║
║                                                               ║
║  Geschätzte Gesamtkosten: 18.547 EUR                          ║
║                                                               ║
║  ℹ️  Hinweis: Preise basieren auf Standard-Preisliste.        ║
║     Diese können in iMOPS angepasst werden.                   ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  [📝 Details bearbeiten]   [❌ Abbrechen]   [✅ Export]       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 4️⃣ Export-Fortschritt

### Wenn User auf "✅ Export" klickt:

```
╔═══════════════════════════════════════════════════════════════╗
║  Exportiere Daten für iMOPS...                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Schritt 1/4: Sicherheits-Daten generieren                    ║
║  ██████████████████████████████  100%                         ║
║  ✅ 5 Gefahrenzonen exportiert                                ║
║                                                               ║
║  Schritt 2/4: Kalkulations-Daten generieren                   ║
║  ███████████████░░░░░░░░░░░░░░░  50%                          ║
║  ⏳ Verarbeite Bauteile...                                    ║
║                                                               ║
║  Schritt 3/4: JSON-Datei erstellen                            ║
║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0%                           ║
║  ⏳ Warten...                                                 ║
║                                                               ║
║  Schritt 4/4: Upload zu iMOPS Cloud (optional)                ║
║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0%                           ║
║  ⏳ Warten...                                                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 5️⃣ Export abgeschlossen

### Nach erfolgreichem Export:

```
╔═══════════════════════════════════════════════════════════════╗
║  ✅ Export erfolgreich!                                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📁 Datei gespeichert:                                        ║
║  /Users/raphael/Documents/Projekte/Mannheim/                  ║
║  mannheim_gewerbepark_export.json                             ║
║                                                               ║
║  Dateigröße: 127 KB                                           ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📤 Exportierte Daten:                                        ║
║                                                               ║
║  ✅ Sicherheits-Daten:                                        ║
║     • 5 Gefahrenzonen                                         ║
║     • 4 Gefahrenquellen (Kran, Stapler, etc.)                 ║
║     • PSA-Anforderungen für alle Zonen                        ║
║                                                               ║
║  ✅ Kalkulations-Daten:                                       ║
║     • 47 Bauteile                                             ║
║     • 156 Flächen (1.245 m²)                                  ║
║     • Geschätzte Kosten: 18.547 EUR                           ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ☁️  Cloud-Sync:                                              ║
║                                                               ║
║  ⦿ Automatisch zu iMOPS hochladen                             ║
║  ○ Nur lokal speichern                                        ║
║                                                               ║
║  [Wenn "Automatisch" gewählt:]                                ║
║  ✅ Projekt in iMOPS Cloud synchronisiert!                    ║
║  Projekt-ID: #MHM-2026-001                                    ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📱 Nächste Schritte:                                         ║
║                                                               ║
║  1. Öffne die iMOPS-App auf deinem iPad                       ║
║  2. Projekt "Mannheim Gewerbepark" erscheint automatisch      ║
║  3. Überprüfe Gefahrenzonen & starte Baustellenplanung        ║
║                                                               ║
║  ODER (wenn lokal gespeichert):                               ║
║                                                               ║
║  1. Öffne iMOPS-App → "Projekt importieren"                   ║
║  2. Wähle Datei: mannheim_gewerbepark_export.json             ║
║  3. Import bestätigen → Fertig!                               ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  [📄 JSON-Datei öffnen]  [📧 Per E-Mail senden]  [✅ Fertig] ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 6️⃣ Einstellungs-Fenster

### Wenn User auf "Extensions → iMOPS → Einstellungen" klickt:

```
╔═══════════════════════════════════════════════════════════════╗
║  iMOPS Construction Grid - Einstellungen                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  👤 Benutzer-Account                                          ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  E-Mail:        [raphael@beispiel.de           ]              ║
║  API-Token:     [••••••••••••••••••••••••••••••]              ║
║                                                               ║
║  Status: ✅ Verbunden mit iMOPS Cloud                         ║
║                                                               ║
║  [🔑 Token neu generieren]  [🚪 Abmelden]                     ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  🏗️ Standard-Werte für neue Exporte                          ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Standard-Bauherr:   [                          ]             ║
║  Standard-Standort:  [Mannheim                  ]             ║
║                                                               ║
║  Automatisch exportieren:                                     ║
║  ☑ Sicherheits-Daten                                          ║
║  ☑ Kalkulations-Daten                                         ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ⚙️ Erkennungs-Einstellungen                                  ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Absturz-Gefahr ab Höhe:      [2.0  ] Meter                   ║
║  Enger Raum unter Fläche:     [15.0 ] m²                      ║
║  Maschinen-Sicherheitsabstand:[10.0 ] Meter                   ║
║                                                               ║
║  Automatisch als Gefahrenzone markieren:                      ║
║  ☑ Alle erkannten Gefahren                                    ║
║  ○ Nur manuelle Auswahl                                       ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  💰 Preislisten (für Kalkulation)                             ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Aktive Preisliste:                                           ║
║  ⦿ Standard-Preisliste (Deutschland 2026)                     ║
║  ○ Eigene Preisliste importieren                              ║
║                                                               ║
║  [📥 Preisliste importieren (CSV/Excel)]                      ║
║                                                               ║
║  Aktuelle Preise (Beispiele):                                 ║
║  • Trockenbau GK 2x12,5mm:    28,50 EUR/m²                    ║
║  • Beton C30/37:              85,00 EUR/m²                    ║
║  • Standardtür 90x210:        450,00 EUR/Stück                ║
║                                                               ║
║  [✏️ Preise bearbeiten]                                       ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📊 Export-Einstellungen                                      ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Standard-Speicherort:                                        ║
║  [/Users/raphael/Documents/Projekte/     ] [📁 Durchsuchen]   ║
║                                                               ║
║  Datei-Format:                                                ║
║  ☑ JSON (für iMOPS)                                           ║
║  ☐ CSV (für Excel)                                            ║
║  ☐ PDF (Übersicht)                                            ║
║                                                               ║
║  Cloud-Sync:                                                  ║
║  ☑ Automatisch nach Export hochladen                          ║
║  ☐ Nur manuell hochladen                                      ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  [💾 Einstellungen speichern]  [↩️ Zurücksetzen]  [✖️ Schließen]║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 7️⃣ Toolbar (optional, für schnellen Zugriff)

### Toolbar im SketchUp-Fenster:

```
SketchUp Haupt-Toolbar (oben):

┌────────────────────────────────────────────────────────┐
│  📏 ✏️ ↩️ 🔄 🔍 🎨 ... [andere Icons]  │ 🏗️ iMOPS  │
└────────────────────────────────────────────────────────┘
                                           ↑
                                  Klicken öffnet:

┌─────────────────────────┐
│ 🏗️ iMOPS Quick-Menu    │
├─────────────────────────┤
│ ⚡ Schnell-Export       │
│ 📊 Modell scannen       │
│ ⚙️ Einstellungen        │
│ ❓ Hilfe                │
└─────────────────────────┘
```

---

## 8️⃣ Kontextmenü (Rechtsklick auf Gruppe)

### Wenn User Rechtsklick auf eine Gruppe macht:

```
Rechtsklick auf Gruppe "Dachgeschoss":

┌─────────────────────────────────────┐
│ ✂️ Cut                               │
│ 📋 Copy                              │
│ 📌 Paste                             │
│ ───────────────────────────────     │
│ 🔒 Lock                              │
│ 🔓 Unlock                            │
│ ───────────────────────────────     │
│ 🏗️ iMOPS Attribute ►               │  ← NEU!
│   ├─ Als Gefahrenzone markieren     │
│   ├─ Risiko-Level setzen ►          │
│   │   ├─ Niedrig                    │
│   │   ├─ Mittel                     │
│   │   └─ Hoch ✓                     │
│   ├─ PSA definieren ►               │
│   │   ├─ ☑ Helm                     │
│   │   ├─ ☑ Absturzsicherung         │
│   │   ├─ ☐ Atemschutz               │
│   │   ├─ ☐ Warnweste                │
│   │   └─ ☐ Sicherheitsschuhe        │
│   └─ Für Kalkulation ignorieren     │
│ ───────────────────────────────     │
│ Entity Info                         │
│ Properties                          │
└─────────────────────────────────────┘
```

---

## 9️⃣ Hilfe-Dialog

### Wenn User auf "Extensions → iMOPS → Hilfe" klickt:

```
╔═══════════════════════════════════════════════════════════════╗
║  iMOPS Construction Grid - Hilfe                              ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📖 Schnellstart-Anleitung                                    ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  1. Modelliere dein Bauvorhaben in SketchUp wie gewohnt       ║
║                                                               ║
║  2. Organisiere dein Modell mit Gruppen:                      ║
║     • Erstelle Gruppen für Bereiche (z.B. "Dachgeschoss")     ║
║     • Nutze Layer/Tags für Gewerke (z.B. "Gerüstbau")         ║
║     • Benenne Gruppen aussagekräftig                          ║
║                                                               ║
║  3. Markiere Gefahrenzonen (optional):                        ║
║     • Rechtsklick auf Gruppe → "iMOPS Attribute"              ║
║     • Risiko-Level setzen (hoch/mittel/niedrig)               ║
║     • PSA-Anforderungen definieren                            ║
║                                                               ║
║  4. Exportiere für iMOPS:                                     ║
║     • Extensions → iMOPS → Export für iMOPS                   ║
║     • Projekt-Info eingeben                                   ║
║     • Export-Optionen wählen                                  ║
║     • "Export" klicken                                        ║
║                                                               ║
║  5. Importiere in iMOPS-App:                                  ║
║     • Automatisch per Cloud-Sync ODER                         ║
║     • Manuelle JSON-Datei importieren                         ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  💡 Tipps & Tricks                                            ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ✓ Nutze aussagekräftige Namen für Gruppen                    ║
║    Gut: "Absturzgefahr Dach", "Staplerweg Außen"             ║
║    Schlecht: "Gruppe 1", "Untitled"                           ║
║                                                               ║
║  ✓ Verwende Layer/Tags für Gewerke:                           ║
║    "Elektrik", "Sanitär", "Trockenbau", "Gerüstbau"           ║
║    → Wird automatisch für Kalkulation gruppiert               ║
║                                                               ║
║  ✓ Setze Materialien korrekt:                                 ║
║    "Gipskarton", "Beton C30", "Holz Fichte"                   ║
║    → Ermöglicht besseres Preis-Matching                       ║
║                                                               ║
║  ✓ Nutze SketchUp-Komponenten für wiederkehrende Objekte:     ║
║    Türen, Fenster, Säulen → Werden automatisch gezählt        ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  ❓ Häufige Fragen (FAQ)                                      ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  F: Werden meine Daten an iMOPS gesendet?                     ║
║  A: Nur wenn du "Cloud-Sync" aktivierst. Ansonsten werden     ║
║     Daten nur lokal als JSON-Datei gespeichert.               ║
║                                                               ║
║  F: Kann ich die Preisliste anpassen?                         ║
║  A: Ja! In Einstellungen → Preislisten → Eigene importieren   ║
║     (CSV/Excel-Format)                                        ║
║                                                               ║
║  F: Was passiert, wenn ich mein Modell ändere?                ║
║  A: Einfach erneut exportieren! iMOPS erkennt das Projekt     ║
║     anhand der Projekt-ID und aktualisiert die Daten.         ║
║                                                               ║
║  F: Funktioniert das Plugin offline?                          ║
║  A: Ja! Export funktioniert komplett offline. Nur Cloud-Sync  ║
║     benötigt Internet.                                        ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  📞 Support & Dokumentation                                   ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  Website:     https://imops.com/construction-grid             ║
║  Dokumentation: https://docs.imops.com/sketchup-plugin        ║
║  E-Mail:      support@imops.com                               ║
║  Video-Tutorials: [▶️ Auf YouTube ansehen]                    ║
║                                                               ║
║  Plugin-Version: 1.0.0                                        ║
║  SketchUp-Version: 2024+                                      ║
║                                                               ║
║  ────────────────────────────────────────────────────         ║
║                                                               ║
║  [📄 Lizenz anzeigen]  [🔄 Nach Updates suchen]  [✖️ Schließen]║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 🎨 Design-Prinzipien

### Warum sieht das UI so aus?

1. **Einfachheit:**
   - Nur 3 Hauptfenster (Export, Einstellungen, Hilfe)
   - Klare Beschriftungen, keine Fachbegriffe

2. **Feedback:**
   - Fortschrittsbalken bei langen Operationen
   - Erfolgs-/Fehler-Meldungen mit Symbolen (✅❌⚠️)
   - Vorschau vor dem Export ("Modell scannen")

3. **Flexibilität:**
   - Schnell-Export für erfahrene User (Toolbar)
   - Ausführliche Optionen für Anfänger (Haupt-Dialog)
   - Einstellungen für individuelle Anpassung

4. **Integration:**
   - Kontextmenü (Rechtsklick) für schnelle Attribute
   - Layer/Tags werden automatisch erkannt
   - Materialien werden automatisch ausgewertet

---

## 📱 User Journey (Beispiel)

### Raphael modelliert "Mannheim Gewerbepark":

```
1. SketchUp öffnen, Modell erstellen
   ├─ Gebäude zeichnen
   ├─ Gruppen erstellen: "Erdgeschoss", "Dachgeschoss", "Außenbereich"
   ├─ Layer/Tags setzen: "Gerüstbau", "Elektrik", "Sanitär"
   └─ Komponenten einfügen: Türen, Fenster, Kran

2. Gefahrenzonen markieren (optional)
   ├─ Rechtsklick auf "Dachgeschoss"
   ├─ iMOPS Attribute → Risiko-Level: "Hoch"
   └─ PSA: Helm ✓, Absturzsicherung ✓

3. Export starten
   ├─ Extensions → iMOPS → Export für iMOPS
   ├─ Projekt-Name eingeben: "Mannheim Gewerbepark"
   ├─ Bauherr: "Müller GmbH"
   ├─ ☑ Sicherheits-Daten ☑ Kalkulations-Daten
   └─ "Export" klicken

4. Vorschau prüfen
   ├─ Plugin zeigt: 5 Gefahrenzonen erkannt
   ├─ Geschätzte Kosten: 18.547 EUR
   └─ "Sieht gut aus!" → Export bestätigen

5. Fertig!
   ├─ JSON-Datei gespeichert
   ├─ Automatisch zu iMOPS Cloud hochgeladen
   └─ Projekt erscheint im iPad

6. Auf der Baustelle
   ├─ iPad öffnen → iMOPS-App
   ├─ Projekt "Mannheim Gewerbepark" ist schon da
   ├─ Gefahrenzonen werden auf 3D-Karte angezeigt
   └─ Mitarbeiter-Check-In startet
```

**Gesamtzeit:** 5-10 Minuten (nach dem Modellieren)

---

## 🔮 Zukunfts-Features (Optional)

### Was könnte noch kommen?

```
╔═══════════════════════════════════════════════════════════════╗
║  🚀 Geplante Features (zukünftige Versionen)                  ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  🤖 KI-Assistent:                                             ║
║     "Erkenne automatisch alle Gefahrenzonen und schlage       ║
║      PSA-Anforderungen vor"                                   ║
║                                                               ║
║  📷 3D-Viewer in iMOPS:                                       ║
║     "Interaktive 3D-Ansicht direkt in der App"                ║
║                                                               ║
║  🔄 Live-Sync:                                                ║
║     "Änderungen in SketchUp werden in Echtzeit zu iMOPS       ║
║      synchronisiert"                                          ║
║                                                               ║
║  📊 Reporting:                                                ║
║     "Erstelle automatisch Sicherheits-Reports als PDF"        ║
║                                                               ║
║  🎤 Sprach-Export:                                            ║
║     "Sage: 'Exportiere für iMOPS' → Plugin startet"           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

**Kannst du dir jetzt vorstellen, wie Raphael mit dem Plugin arbeiten würde?** 🎯
