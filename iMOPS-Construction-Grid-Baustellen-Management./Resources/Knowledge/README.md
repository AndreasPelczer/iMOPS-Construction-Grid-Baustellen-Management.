# iMOPS Exact-Match-Knowledge

Hier liegen die YAML-Dateien für den **iOS-side Pre-Filter**: deterministische
Antworten auf häufige Bau-Fachfragen (DIN-Normen, Festigkeitsklassen, WLG-Werte,
Mörtelgruppen).

Beim Start der App wird `ExactMatchKnowledge.swift` alle YAMLs aus diesem
Verzeichnis laden. Vor jeder `/chat`-Anfrage an den Mops-Server wird zuerst
hier nachgeschaut. Bei einem Treffer wird die lokale Antwort sofort zurückgegeben
— **kein Netzwerk-Call, kein LLM, sub-millisekunde Latenz, offline-fähig**.

## Aktuelle Dateien

| Datei | Kategorie | Inhalt |
|-------|-----------|--------|
| `din_normen.yaml` | fachwissen | DIN-Normen-Übersicht (DIN 276, 277, 1045, EN 1992, 18195, 18560, HOAI, VOB, GAEB, REB) |
| `betongueten.yaml` | fachwissen | Beton-Festigkeitsklassen (C20/25 bis C35/45) + Expositionsklassen |
| `wlg_werte.yaml` | fachwissen | Wärmeleitgruppen (WLG 032/035/040) + U-Wert |
| `moertelgruppen.yaml` | fachwissen | Mörtelgruppen (MG II/IIa/III) + Dünnbettmörtel |
| `app_bedienung.yaml` | app-bedienung | iMOPS-Bedienungshilfe (Baustelle/Auftrag/Mangel anlegen, GAEB-Import, BauWissen, PDF-Export, CAD-Viewer, BuildIQ) |

### Zwei Kategorien — warum

- **`fachwissen`** — objektive Bau-Fakten (DIN-Normen, Materialwerte). Source-Card im UI: 📖 "Aus Bau-Wissen"
- **`app-bedienung`** — deterministische Hilfe-Texte zur App selbst (Buttons, Tabs, Workflows). Source-Card im UI: 🔧 "Bedienungshilfe"

Beide laufen durch denselben Lookup, werden aber im UI unterschiedlich dargestellt damit User wissen ob die Antwort aus dem Bau-Domain oder über die App selbst stammt.

## Schema

Jeder Eintrag in einer YAML-Liste:

```yaml
- id: "DIN_276"               # eindeutige ID, intern
  kategorie: "fachwissen"     # optional, default "fachwissen". "app-bedienung" für App-Hilfe.
  app_version_min: "1.0"      # optional, NUR bei kategorie: app-bedienung sinnvoll
  aliases:                    # case-insensitive Suchbegriffe
    - "DIN 276"
    - "DIN-276"
    - "Kostengruppen"
  antwort: |                  # Mehrzeiliger Text, kein Norm-Wortlaut
    DIN 276 strukturiert Baukosten in 100er-Hauptgruppen:
    - 100 Grundstück
    - 200 Vorbereitende Maßnahmen
    ...
  quelle_kurz: "DIN 276:2018-12 (Kosten im Bauwesen)"
  quelle_url: ""              # optional
  license_note: "Werte und Kurzbeschreibung — Volltext bei Beuth"
```

## Such-Logik

`ExactMatchKnowledge.lookup(question)` macht:
1. Normalisiert die Frage zu lowercase
2. Sucht in allen `aliases` nach `contains`-Match
3. **Längster passender Alias gewinnt** — "DIN EN 1992-1-1" schlägt "DIN 1992"
4. Gibt den vollständigen `KnowledgeEntry` zurück oder `nil`

## Lizenz-Regel (WICHTIG)

- `antwort:` darf **nur Sachverhalte/Werte** enthalten — Definitionen,
  Wertebereiche, Anwendungsbereiche, Gliederungen.
- **Kein Norm-Wortlaut** kopieren. Volltexte sind Beuth-lizenziert.
- Faustregel: wenn ein Absatz so klingt wie aus der Norm zitiert →
  in eigenen Worten neu formulieren.
- Pro `antwort:` Feld max ~500 Zeichen empfohlen.

## Neue Einträge hinzufügen

1. Passende YAML wählen (oder neue YAML anlegen für neuen Themenbereich)
2. Eintrag im obigen Schema schreiben
3. Aliases großzügig setzen — alle Schreibweisen die in Fragen vorkommen können
   ("DIN 276", "DIN-276", "Kostengruppe", "KG nach DIN")
4. PR aufmachen, von Raffi/Codi-Review prüfen lassen
5. Nach Merge: App neu bauen, dann ist Eintrag aktiv

## Wo das aufläuft

- `iMOPS-Construction-Grid-Baustellen-Management./Service/ExactMatchKnowledge.swift` — Loader + Lookup
- Wird vor jeder `MopsClient.ask()` aufgerufen
- Bei Hit: Source = "din-table-local" (vs "mops" / "prof" / "cached-echo")
