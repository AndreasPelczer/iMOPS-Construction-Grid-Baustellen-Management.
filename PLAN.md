# Plan: Baustellen-Umbau + CAD-Viewer

## Überblick

Zwei Hauptaufgaben:
1. **Domain-Umbau**: Catering-Logik komplett durch Baustellen-Logik ersetzen
2. **CAD-Viewer**: 3D-Dateien (USDZ) in der App anzeigen (drehen, zoomen)

---

## Phase 1: Baustellen-Umbau (Domain-Konvertierung)

### 1.1 Vorlagen ersetzen (`AuftragTemplate.swift`)
- **Vorher**: Setzarbeiten, Spätzle, Bulgur, Buffet
- **Nachher**: Rohbau, Elektroinstallation, Sanitär, Malerarbeiten, Estrich, Trockenbau
- Jede Vorlage bekommt passende Checklisten-Schritte (z.B. Rohbau → Schalung, Bewehrung, Betonieren, Aushärten)

### 1.2 UI-Texte & Labels anpassen
- "Event" → "Baustelle" (in Views, Navigation, Buttons)
- "Aufträge" bleibt (passt für beide Domänen)
- Tab-Titel anpassen: "Baustellen" statt "Zu erledigen"
- Filter-Labels anpassen: "Aktive Baustellen", "Abgeschlossen", "Alle"

### 1.3 Produkt/Zutaten-Modelle ersetzen
- `CDProduct` (Nährwerte, Allergene) → **Material** (Einheit, Menge, Lieferant)
- `CDIngredient` → entfernen oder zu Material-Positionen umbauen
- `CDLexikonEntry` → Bau-Lexikon (Normen, Gewerke, Baustoffe)

### 1.4 Event-Entity erweitern für Baustellen-Kontext
- Neue Felder im Core Data Modell:
  - `bauherr` (String) - Auftraggeber
  - `architekt` (String)
  - `baugenehmigungNr` (String)
  - `gewerk` (String) - Hauptgewerk
- `extras` JSON-Payload anpassen für Bau-Checklisten

### 1.5 DemoSeeder aktualisieren
- Demo-Baustelle statt Demo-Event erstellen
- Realistische Bau-Aufträge (Elektrik EG, Sanitär OG, etc.)

### 1.6 AuftragExtrasPayload anpassen
- `allergenSummary` → entfernen
- `nutritionSnapshot` → entfernen
- Neue Felder: `gewerk`, `materialListe`, `planReferenz` (Verweis auf CAD-Datei)

---

## Phase 2: CAD/3D-Viewer Integration

### 2.1 Dateiformat-Strategie (Best Practice)
- **Primärformat**: USDZ (Apple-nativ, von SceneKit und Quick Look unterstützt)
- **Zusätzlich unterstützt**: .obj, .dae (Collada) - gängige Export-Formate aus SketchUp
- **Workflow für Benutzer**: SketchUp → Export als .obj/.dae → Reality Converter → .usdz
  (oder direkte USDZ-Plugins für SketchUp)

### 2.2 Datei-Import via Document Picker
- Neuer Button "Plan importieren" in der Baustellen-Detail-Ansicht
- iOS Document Picker (UTType: .usdz, .obj, .dae)
- Dateien werden in App-Sandbox kopiert (Documents/CADFiles/{baustelleID}/)
- Core Data: Neues Entity `CADFile` (name, filePath, importDate, baustelleID)

### 2.3 3D-Viewer View (SceneKit-basiert)
- Neue View: `CADViewerView.swift`
- SceneKit SCNView in SwiftUI (UIViewRepresentable)
- Features:
  - Orbit-Kamera (Drehen mit Finger)
  - Pinch-to-Zoom
  - Pan zum Verschieben
  - Reset-Button (Zurück zur Ausgangsposition)
- Alternativ: Quick Look Preview als Fallback (noch einfacher, weniger Kontrolle)

### 2.4 CAD-Dateien an Baustelle/Auftrag verknüpfen
- In EventDetailView: Neue Section "Pläne & CAD"
- Liste der importierten CAD-Dateien
- Tap → Öffnet CAD-Viewer
- Optional: Auftrag kann auf bestimmten Plan verweisen

### 2.5 Beispiel-Dateien bündeln
- 1-2 einfache USDZ-Dateien als Demo-Content einbetten
- DemoSeeder verknüpft sie mit der Demo-Baustelle

---

## Reihenfolge der Umsetzung

| Schritt | Was | Dateien |
|---------|-----|---------|
| 1 | Vorlagen ersetzen | `AuftragTemplate.swift` |
| 2 | UI-Texte Baustelle | `RootTabView`, `ContentView`, `EventDetailView`, `EventFilterPicker`, etc. |
| 3 | EventFilter umbenennen | `EventListViewModel.swift`, `EventFilterPicker.swift` |
| 4 | Extras-Payload anpassen | `AuftragChecklistItem.swift`, `EventDetailView.swift` |
| 5 | Core Data erweitern | `test25B.xcdatamodel`, neue Entity `CADFile` |
| 6 | DemoSeeder updaten | `DemoSeeder.swift` |
| 7 | Document Picker bauen | Neue View `CADImportView.swift` |
| 8 | SceneKit 3D-Viewer | Neue View `CADViewerView.swift` |
| 9 | CAD-Section in Detail | `EventDetailView.swift` erweitern |
| 10 | Beispiel-USDZ einbetten | Assets + DemoSeeder |

---

## Technische Abhängigkeiten (neue Imports)

```swift
import SceneKit        // 3D-Rendering
import UniformTypeIdentifiers  // Document Picker (UTType)
import QuickLook       // Optional: QLPreviewController als Fallback
```

## Kein externer Dependency nötig
Alles mit Apple-eigenen Frameworks lösbar.
