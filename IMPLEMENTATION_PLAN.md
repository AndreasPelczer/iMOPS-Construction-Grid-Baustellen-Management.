# iMOPS Construction Grid – Implementierungsplan

## 🎯 Überblick

Dieses Dokument beschreibt die technische Umsetzung des iMOPS Construction Grid Systems. Es definiert die Software-Architektur, den Technologie-Stack, die Entwicklungsphasen und die konkreten Implementierungsschritte.

---

## 🏗️ System-Architektur

### Komponenten-Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│                    BAUSTELLEN-PLANUNG                        │
│  ┌──────────────┐      ┌─────────────────────────────┐     │
│  │ Excel-Vorlagen│ ───► │  SketchUp Plugin (Raphael)  │     │
│  │  (Parameter)  │      │   - Ruby API                │     │
│  └──────────────┘      │   - 3D-Generierung          │     │
│                         │   - Export → JSON           │     │
│                         └─────────────────────────────┘     │
│                                      │                       │
│                                      ▼                       │
└──────────────────────────────────────┼───────────────────────┘
                                       │
                         ┌─────────────▼─────────────┐
                         │   JSON-Schnittstelle      │
                         │   (Baustellen-Definition) │
                         └─────────────┬─────────────┘
                                       │
┌──────────────────────────────────────┼───────────────────────┐
│                   iMOPS CORE SYSTEM                          │
│                                      ▼                       │
│  ┌────────────────────────────────────────────────────┐     │
│  │           Baustellen-Modul (Swift/SwiftUI)         │     │
│  │  ┌──────────────────────────────────────────────┐ │     │
│  │  │  3D-Import & Visualisierung                  │ │     │
│  │  │  - Baustellen-Karte                          │ │     │
│  │  │  - Gefahrenzonen                             │ │     │
│  │  │  - Sicherheitsbereiche                       │ │     │
│  │  └──────────────────────────────────────────────┘ │     │
│  │  ┌──────────────────────────────────────────────┐ │     │
│  │  │  Compliance-Engine                           │ │     │
│  │  │  - Baustellenverordnung (BaustellV)          │ │     │
│  │  │  - DGUV Vorschrift 1 & 38                    │ │     │
│  │  │  - Arbeitsstättenverordnung (ArbStättV)      │ │     │
│  │  │  - Regelprüfung in Echtzeit                  │ │     │
│  │  └──────────────────────────────────────────────┘ │     │
│  │  ┌──────────────────────────────────────────────┐ │     │
│  │  │  Mitarbeiter-Management                      │ │     │
│  │  │  - Check-In/Check-Out                        │ │     │
│  │  │  - Unterweisungs-Tracking                    │ │     │
│  │  │  - Qualifikations-Verwaltung                 │ │     │
│  │  └──────────────────────────────────────────────┘ │     │
│  │  ┌──────────────────────────────────────────────┐ │     │
│  │  │  Aufgaben-Management                         │ │     │
│  │  │  - Zuweisung nach Bereichen                  │ │     │
│  │  │  - Status-Tracking                           │ │     │
│  │  │  - Compliance-Checks                         │ │     │
│  │  └──────────────────────────────────────────────┘ │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │              ChefIQ-Integration                    │     │
│  │  - Foto-Dokumentation (Camera API)                 │     │
│  │  - GPS-Verortung (Location Services)               │     │
│  │  - Zeitstempel-Verifizierung                       │     │
│  │  - Soll-Ist-Vergleich                              │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Maierindex-Modul                      │     │
│  │  - KPI-Berechnung                                  │     │
│  │  - Trendanalyse                                    │     │
│  │  - Report-Generierung                              │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Persistenz-Layer (Core Data)               │     │
│  │  - Offline-First                                   │     │
│  │  - Hash-Chain für Manipulationsschutz              │     │
│  │  - Optional: Cloud-Sync                            │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

---

## 💻 Technologie-Stack

### SketchUp-Komponente (Raphael)
| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| **Plugin-Sprache** | Ruby | SketchUp API-Zugriff |
| **3D-Bibliothek** | SketchUp API | Geometrie-Erstellung |
| **Import** | Excel via RubyXL/Spreadsheet gem | Parameter einlesen |
| **Export** | JSON | Datenübergabe an iMOPS |
| **UI** | SketchUp::UI | Benutzeroberfläche im Plugin |

**Schlüssel-Abhängigkeiten:**
```ruby
# Gemfile (falls externe Gems benötigt werden)
source 'https://rubygems.org'

gem 'json'           # JSON-Export
gem 'rubyXL'         # Excel-Import (.xlsx)
gem 'nokogiri'       # XML-Verarbeitung (optional)
```

---

### iMOPS-Komponente (Core System)
| Komponente | Technologie | Zweck |
|------------|-------------|-------|
| **Sprache** | Swift 5.9+ | Native iOS/iPadOS App |
| **UI-Framework** | SwiftUI | Moderne, deklarative UI |
| **Persistenz** | Core Data | Offline-First Datenhaltung |
| **Netzwerk** | URLSession / Async/Await | Cloud-Sync (optional) |
| **Kamera** | AVFoundation | ChefIQ Foto-Dokumentation |
| **Location** | CoreLocation | GPS-Verortung |
| **Security** | CryptoKit | Hash-Chain (SHA-256) |
| **PDF-Export** | PDFKit | Berichte & Audit-Protokolle |
| **3D-Visualisierung** | SceneKit / RealityKit | Baustellen-Karte anzeigen |

**Projekt-Struktur:**
```
iMOPS-Construction/
├── App/
│   ├── iMOPSConstructionApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── ConstructionSite.swift
│   ├── SafetyZone.swift
│   ├── Employee.swift
│   ├── Task.swift
│   └── ComplianceRule.swift
├── Views/
│   ├── ConstructionSiteMapView.swift
│   ├── EmployeeDashboardView.swift
│   ├── ComplianceChecklistView.swift
│   └── ChefIQ/
│       ├── PhotoCaptureView.swift
│       └── PhotoReviewView.swift
├── ViewModels/
│   ├── ConstructionSiteViewModel.swift
│   ├── ComplianceViewModel.swift
│   └── MaierindexViewModel.swift
├── Services/
│   ├── ComplianceEngine.swift
│   ├── JSONImportService.swift
│   ├── HashChainService.swift
│   └── ReportGenerator.swift
├── Utilities/
│   ├── Constants.swift
│   └── Extensions.swift
└── Resources/
    ├── ComplianceRules/
    │   ├── BaustellV.json
    │   ├── DGUV.json
    │   └── ArbStättV.json
    └── Assets.xcassets/
```

---

## 🔗 Daten-Schnittstellen

### JSON-Format: SketchUp → iMOPS

**Baustellendefinition (ConstructionSite.json):**
```json
{
  "version": "1.0",
  "constructionSite": {
    "id": "CS-2026-001",
    "name": "Neubau Gewerbepark Ost",
    "address": {
      "street": "Industriestraße 42",
      "city": "München",
      "postalCode": "80331",
      "country": "Deutschland"
    },
    "coordinates": {
      "latitude": 48.1351,
      "longitude": 11.5820
    },
    "startDate": "2026-03-01",
    "endDate": "2026-08-31",
    "dimensions": {
      "length": 120.0,
      "width": 80.0,
      "boundingBox": {
        "min": { "x": 0, "y": 0, "z": 0 },
        "max": { "x": 120, "y": 80, "z": 25 }
      }
    },
    "zones": [
      {
        "id": "ZONE-001",
        "name": "Kranbereich Nord",
        "type": "crane_operation",
        "safetyLevel": "high_risk",
        "geometry": {
          "type": "polygon",
          "coordinates": [
            [10, 10, 0],
            [30, 10, 0],
            [30, 30, 0],
            [10, 30, 0]
          ]
        },
        "requiredPPE": ["hard_hat", "safety_boots", "high_vis_vest"],
        "accessRestrictions": ["crane_operator_license"],
        "complianceRules": ["BAU-SCP-01", "DGUV-38-§12"]
      },
      {
        "id": "ZONE-002",
        "name": "Gerüstbereich Süd",
        "type": "scaffolding",
        "safetyLevel": "medium_risk",
        "geometry": {
          "type": "polygon",
          "coordinates": [
            [50, 5, 0],
            [70, 5, 0],
            [70, 15, 0],
            [50, 15, 0]
          ]
        },
        "maxHeight": 12.0,
        "fallProtectionRequired": true,
        "requiredPPE": ["hard_hat", "safety_boots", "safety_harness"],
        "complianceRules": ["BAU-SCP-01", "BAU-SCP-03"]
      }
    ],
    "accessPoints": [
      {
        "id": "ACCESS-01",
        "name": "Hauptzufahrt",
        "type": "vehicle_gate",
        "coordinates": { "x": 0, "y": 40, "z": 0 },
        "width": 6.0,
        "accessControl": true
      },
      {
        "id": "ACCESS-02",
        "name": "Fußgänger-Eingang",
        "type": "pedestrian_gate",
        "coordinates": { "x": 0, "y": 55, "z": 0 },
        "width": 2.0,
        "checkInRequired": true
      }
    ],
    "equipment": [
      {
        "id": "CRANE-001",
        "name": "Turmdrehkran #1",
        "type": "tower_crane",
        "position": { "x": 20, "y": 20, "z": 0 },
        "height": 35.0,
        "radius": 25.0,
        "safetyZoneRadius": 30.0,
        "inspectionInterval": "weekly",
        "lastInspection": "2026-02-10"
      }
    ]
  }
}
```

**Compliance-Regeln (ComplianceRules.json):**
```json
{
  "rules": [
    {
      "id": "BAU-SCP-01",
      "lawReference": "BaustellV § 4 Abs. 1",
      "category": "fall_protection",
      "title": "Absturzsicherung",
      "description": "Ab 2m Arbeitshöhe ist eine wirksame Absturzsicherung erforderlich",
      "trigger": {
        "condition": "work_height >= 2.0",
        "unit": "meters"
      },
      "requiredActions": [
        "absturzsicherung_vorhanden",
        "mitarbeiter_unterweisung_aktuell"
      ],
      "severity": "critical",
      "checkFrequency": "before_work_start"
    },
    {
      "id": "DGUV-38-§12",
      "lawReference": "DGUV Vorschrift 38 § 12",
      "category": "crane_operation",
      "title": "Kranführer-Qualifikation",
      "description": "Krane dürfen nur von unterwiesenen und beauftragten Personen bedient werden",
      "trigger": {
        "condition": "employee_enters_zone AND zone.type == 'crane_operation'"
      },
      "requiredActions": [
        "kranfuehrer_schein_gueltig",
        "jaehrliche_unterweisung_aktuell"
      ],
      "severity": "critical",
      "checkFrequency": "on_zone_entry"
    },
    {
      "id": "BAU-SCP-03",
      "lawReference": "BaustellV § 12 Abs. 2",
      "category": "scaffolding",
      "title": "Gerüstprüfung",
      "description": "Gerüste müssen vor der ersten Ingebrauchnahme und danach mind. alle 7 Tage geprüft werden",
      "trigger": {
        "condition": "scaffolding_usage"
      },
      "requiredActions": [
        "geruest_pruefung_max_7_tage_alt",
        "pruefbuch_vollstaendig"
      ],
      "severity": "high",
      "checkFrequency": "weekly"
    }
  ]
}
```

---

## 📋 Entwicklungsphasen

### Phase 1: Foundation (Monate 1-2)

**Ziel:** Grundarchitektur + SketchUp-Integration

#### 1.1 SketchUp-Plugin (Raphael)
- [ ] **Woche 1-2:** Excel-Import entwickeln
  - RubyXL gem einbinden
  - Excel-Parser für Baustellenparameter
  - Validierung der Eingabedaten

- [ ] **Woche 3-4:** 3D-Generierung
  - Automatische Geometrie-Erstellung
  - Zonen-Visualisierung (farbcodiert)
  - Equipment-Platzierung (Krane, Gerüste)

- [ ] **Woche 5-6:** JSON-Export
  - JSON-Serialisierung
  - Schema-Validierung
  - Test-Daten generieren

- [ ] **Woche 7-8:** UI + Testing
  - SketchUp-Menü-Integration
  - User-Feedback bei Fehlern
  - Testfälle mit verschiedenen Baustellengrößen

**Deliverable:** SketchUp-Plugin v0.1 (funktionsfähig für 1 Testbaustelle)

#### 1.2 iMOPS Core Setup
- [ ] **Woche 1-2:** Projekt-Setup
  - Xcode-Projekt anlegen
  - Core Data Model definieren
  - SwiftUI Navigation-Struktur

- [ ] **Woche 3-4:** JSON-Import
  - JSON-Parser für ConstructionSite
  - Mapping auf Core Data Entities
  - Import-Validierung

- [ ] **Woche 5-6:** Basis-UI
  - Baustellenübersicht (Liste)
  - Einfache 2D-Karte (erste Version)
  - Zonen-Detailansicht

- [ ] **Woche 7-8:** Daten-Persistenz
  - Core Data Integration
  - Offline-Funktionalität testen
  - Basis-Synchronisation

**Deliverable:** iMOPS iOS App v0.1 (kann SketchUp-JSON importieren + anzeigen)

---

### Phase 2: Compliance Engine (Monate 3-4)

**Ziel:** Regelwerk implementieren + automatische Validierung

#### 2.1 Compliance-Regeln kodifizieren
- [ ] **Woche 1-2:** Regelwerk digitalisieren
  - BaustellV in JSON übersetzen
  - DGUV Vorschrift 1 & 38
  - ArbStättV (relevante Teile)
  - JSON-Schema für Regeln definieren

- [ ] **Woche 3-4:** Compliance-Engine bauen
  ```swift
  class ComplianceEngine {
      func checkRule(_ rule: ComplianceRule,
                     context: ComplianceContext) -> ComplianceResult
      func evaluateTrigger(_ trigger: RuleTrigger) -> Bool
      func enforceActions(_ actions: [RequiredAction]) -> [ActionResult]
  }
  ```

- [ ] **Woche 5-6:** Event-System
  - Employee Check-In → Compliance-Check
  - Zone-Entry → Regel-Validierung
  - Task-Assignment → PPE-Prüfung

- [ ] **Woche 7-8:** Warning-System
  - Echtzeit-Warnungen bei Verstößen
  - Eskalationsstufen (Info/Warnung/Kritisch)
  - Push-Notifications

**Deliverable:** Funktionierende Compliance-Engine mit 10+ Regeln

#### 2.2 Mitarbeiter-Management
- [ ] **Woche 1-3:** Employee-Datenmodell
  - Qualifikationen
  - Unterweisungen (mit Gültigkeitsdatum)
  - PPE-Zuweisungen

- [ ] **Woche 4-6:** Check-In/Out-System
  - PIN/Touch ID Authentifizierung
  - Automatische Compliance-Checks
  - Tages-Aufgaben anzeigen

- [ ] **Woche 7-8:** Schulungsnachweise
  - Unterweisung dokumentieren
  - Digitale Unterschrift
  - Ablaufdatum-Tracking

**Deliverable:** Vollständiges Mitarbeiter-Management-Modul

---

### Phase 3: ChefIQ Integration (Monate 5-6)

**Ziel:** Foto-Dokumentation + Beweissicherung

#### 3.1 Foto-Modul
- [ ] **Woche 1-2:** Kamera-Integration
  ```swift
  class ChefIQPhotoService {
      func capturePhoto(for task: Task) -> ChefIQPhoto
      func addMetadata(_ photo: inout ChefIQPhoto)
      func verifyIntegrity(_ photo: ChefIQPhoto) -> Bool
  }
  ```
  - AVFoundation Camera
  - Automatischer Zeitstempel (Server-Zeit für Manipulationsschutz)
  - GPS-Koordinaten

- [ ] **Woche 3-4:** Hash-Chain Implementation
  ```swift
  struct ChefIQPhoto {
      let id: UUID
      let imageData: Data
      let timestamp: Date
      let gpsCoordinates: CLLocationCoordinate2D?
      let taskID: UUID?
      let employeeID: UUID

      // Manipulationsschutz
      let previousPhotoHash: String?
      let currentHash: String  // SHA-256 über alle Felder
  }
  ```

- [ ] **Woche 5-6:** Soll-Ist-Vergleich
  - 3D-Modell als "Soll"
  - Foto-Overlay für Vergleich
  - Abweichungen markieren

- [ ] **Woche 7-8:** Foto-Galerie + Export
  - Chronologische Ansicht
  - Filter (Datum/Zone/Mitarbeiter)
  - PDF-Export für Audit

**Deliverable:** ChefIQ-Modul mit manipulationssicherer Foto-Dokumentation

---

### Phase 4: Maierindex & Reporting (Monate 7-8)

**Ziel:** KPI-System + automatische Berichte

#### 4.1 Maierindex-Berechnung
- [ ] **Woche 1-2:** KPI-Definition
  ```swift
  struct Maierindex {
      let complianceRate: Double      // 0-100%
      let responseTime: TimeInterval   // Durchschnitt
      let documentationQuality: Double // 0-100%
      let accidentScore: Double        // Inverse Unfallrate
      let auditReadiness: Double       // 0-100%

      var overallScore: Double {
          // Gewichtete Formel
      }
  }
  ```

- [ ] **Woche 3-4:** Trend-Analyse
  - Tägliche/Wöchentliche/Monatliche Scores
  - Charts mit Swift Charts
  - Schwellwerte für Alarme

- [ ] **Woche 5-6:** Benchmark-System
  - Vergleich zwischen Baustellen
  - Branchen-Durchschnitt (optional)
  - Versicherungs-Schwellwerte

**Deliverable:** Maierindex-Dashboard mit Echtzeit-Updates

#### 4.2 Report-Generator
- [ ] **Woche 1-3:** PDF-Templates
  - Täglicher Sicherheitsbericht
  - Wöchentlicher Compliance-Report
  - Monatliches Audit-Protokoll

- [ ] **Woche 4-6:** Export-Funktionen
  - CSV für Zeiterfassung
  - JSON API für externe Systeme
  - Email-Versand

- [ ] **Woche 7-8:** Automatisierung
  - Scheduled Reports
  - Auto-Export zu BG/Versicherung
  - Push bei kritischen Ereignissen

**Deliverable:** Vollautomatisches Reporting-System

---

### Phase 5: 3D-Visualisierung & Polish (Monate 9-10)

**Ziel:** Intuitive Baustellen-Karte + UX-Verbesserungen

#### 5.1 3D-Integration
- [ ] **Woche 1-4:** SceneKit/RealityKit
  - SketchUp-Geometrie importieren
  - Interaktive 3D-Karte
  - Zoom/Pan/Rotate
  - Zonen-Highlighting

- [ ] **Woche 5-6:** AR-Modus (optional)
  - ARKit-Integration
  - Baustelle in realer Umgebung überlagern
  - Gefahrenzonen visualisieren

**Deliverable:** Immersive 3D-Baustellenkarte

#### 5.2 UX/UI-Verbesserungen
- [ ] User-Testing mit echten Bauleitern
- [ ] Performance-Optimierung
- [ ] Accessibility (VoiceOver, Dynamic Type)
- [ ] iPad-Multitasking
- [ ] Arbeitshandschuh-freundliche Buttons

---

### Phase 6: Pilot & Iteration (Monate 11-12)

**Ziel:** Reale Baustelle + Feedback-Integration

#### 6.1 Pilot-Deployment
- [ ] 1 mittelgroße Baustelle (3-6 Monate Laufzeit)
- [ ] 10-20 Mitarbeiter + 2 Bauleiter
- [ ] Wöchentliche Feedback-Runden
- [ ] Bug-Fixing im 2-Tages-Zyklus

#### 6.2 Success-Metriken messen
- ✅ 3D-Modell in < 1 Stunde generierbar?
- ✅ Maierindex > 85 im ersten Monat?
- ✅ 0 Arbeitsinspektorat-Mängel?
- ✅ Versicherung bestätigt Prämienreduktion?

#### 6.3 Iteration
- [ ] Raphael: SketchUp-Plugin verbessern basierend auf Feedback
- [ ] iMOPS: UI/UX-Anpassungen
- [ ] Dokumentation vervollständigen

**Deliverable:** Produktionsreife v1.0

---

## 🔐 Sicherheit & Compliance

### Technische Maßnahmen

#### 1. Manipulationsschutz
```swift
// Hash-Chain Implementation
class HashChainService {
    func calculateHash(for record: Hashable) -> String {
        let data = encode(record)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func verifyChain(records: [HashableRecord]) -> Bool {
        for i in 1..<records.count {
            guard records[i].previousHash == records[i-1].currentHash else {
                return false
            }
        }
        return true
    }
}
```

#### 2. DSGVO-Compliance
- **Zweckbindung:** Nur Sicherheitsdaten speichern
- **Datensparsamkeit:** Kein GPS-Tracking von Personen
- **Löschfristen:** Automatische Anonymisierung nach gesetzlicher Frist
- **Auskunftsrecht:** Export aller personenbezogenen Daten

#### 3. Offline-Security
- **Verschlüsselung:** Core Data mit FileProtection
- **Biometrische Auth:** Face ID / Touch ID
- **Auto-Lock:** Nach 5 Min Inaktivität

---

## 🧪 Testing-Strategie

### Unit Tests
```swift
// Beispiel: Compliance-Engine Tests
class ComplianceEngineTests: XCTestCase {
    func testFallProtectionRule() {
        let rule = ComplianceRule.fallProtection
        let context = ComplianceContext(
            workHeight: 2.5,
            employee: employee,
            zone: zone
        )

        let result = engine.checkRule(rule, context: context)
        XCTAssertEqual(result.status, .violated)
        XCTAssertTrue(result.requiredActions.contains(.absturzsicherungVorhanden))
    }
}
```

### Integration Tests
- SketchUp JSON → iMOPS Import
- Compliance Rule Trigger → Warning
- Photo Capture → Hash-Chain

### UI Tests
- Check-In Flow
- Task Assignment
- Photo Documentation

---

## 📊 Deployment-Plan

### Beta-Phase
1. **TestFlight:** Interne Tests (iMOPS-Team + Raphael)
2. **Closed Beta:** 3 freundliche Baustellen
3. **Open Beta:** 10 weitere Baustellen

### Production
1. **App Store:** iOS/iPadOS App
2. **Enterprise:** MDM-Integration für Baufirmen
3. **SketchUp Extension Warehouse:** Raphael's Plugin

---

## 📈 Erfolgs-Metriken

### Technische KPIs
- **Import-Zeit:** < 5 Sekunden für 100-Zonen-Baustelle
- **App-Startup:** < 2 Sekunden (Cold Start)
- **Offline-Fähigkeit:** 100% aller Core-Features
- **Crash-Rate:** < 0.1%

### Business KPIs
- **User-Adoption:** > 80% tägliche Nutzung
- **Maierindex:** Durchschnitt > 85
- **Versicherungs-Bonus:** Mind. 10% bei 50% der Piloten
- **NPS (Net Promoter Score):** > 50

---

## 🤝 Team-Rollen

### Raphael (SketchUp-Experte)
- **Verantwortlich für:**
  - SketchUp-Plugin Entwicklung
  - Excel-Template Design
  - 3D-Modell-Generierung
  - Baustellenplanung-Workflows

- **Zusammenarbeit:**
  - Wöchentliche Sync-Meetings mit iMOPS-Team
  - JSON-Schema gemeinsam definieren
  - Testdaten für verschiedene Baustellentypen

### iMOPS-Team
- **Verantwortlich für:**
  - iOS App Entwicklung
  - Compliance-Engine
  - ChefIQ-Integration
  - Backend (falls Cloud-Sync)

- **Zusammenarbeit:**
  - JSON-Import-Tests mit Raphael's Daten
  - Feedback zu benötigten 3D-Daten
  - UX-Anforderungen kommunizieren

---

## 🛠️ Entwicklungs-Tools

### Raphael (Ruby/SketchUp)
- **IDE:** Visual Studio Code + Ruby Extension
- **SketchUp:** Pro 2024+
- **Excel:** Microsoft Excel / LibreOffice Calc
- **Version Control:** Git + GitHub
- **Testing:** Minitest (Ruby Unit Tests)

### iMOPS (Swift/iOS)
- **IDE:** Xcode 15+
- **Language:** Swift 5.9+
- **UI:** SwiftUI + Swift Charts
- **Testing:** XCTest + XCUITest
- **CI/CD:** GitHub Actions → TestFlight
- **Design:** Figma (für UI-Mockups)

### Gemeinsam
- **Kommunikation:** Slack / Discord
- **Projekt-Management:** GitHub Projects
- **Dokumentation:** Markdown (GitHub Wiki)
- **API-Spec:** JSON Schema Validator

---

## 💰 Kosten-Schätzung

### Entwicklung (12 Monate)
- **Raphael (SketchUp-Plugin):** 200-300 Stunden
- **iMOPS-Team (iOS App):** 800-1000 Stunden
- **Gesamt:** ~1200 Stunden

### Infrastruktur (pro Jahr)
- **Apple Developer Program:** 99€
- **Cloud-Hosting (optional):** 50-200€/Monat
- **CI/CD (GitHub Actions):** Gratis (Open Source)
- **Gesamt:** ~100-2500€/Jahr

---

## 🚀 Go-Live-Checkliste

### Pre-Launch
- [ ] Alle Unit Tests grün
- [ ] UI Tests auf 3 verschiedenen iPads
- [ ] Performance-Benchmarks erfüllt
- [ ] Datenschutzerklärung fertig
- [ ] App Store Assets (Screenshots, Video)
- [ ] Versicherung kontaktiert (Prämien-Vereinbarung)

### Launch-Tag
- [ ] App Store Submission
- [ ] SketchUp Extension Warehouse Submission
- [ ] Dokumentation veröffentlichen (README, Tutorials)
- [ ] Support-Kanal einrichten (Email/Slack)

### Post-Launch (erste 30 Tage)
- [ ] Täglich Crash-Reports prüfen
- [ ] User-Feedback sammeln
- [ ] Wöchentliche Updates bei kritischen Bugs
- [ ] Erste Versicherungs-Reports einreichen

---

## 📝 Offene Fragen

### Technisch
1. **Cloud-Sync:** Eigener Server oder Firebase/AWS?
2. **Multi-Tenant:** Mehrere Baufirmen in einer App oder getrennte Instanzen?
3. **API:** REST oder GraphQL (falls externe Integration)?
4. **Sprachen:** Nur Deutsch oder auch Englisch/Französisch/Italienisch?

### Rechtlich
1. **Haftung:** Wer haftet bei Software-Fehlern (Disclaimer)?
2. **Lizenzierung:** Open Source (MIT/GPL) oder proprietär?
3. **Datenschutz:** Wo werden Cloud-Daten gehostet (Deutschland/EU)?

### Business
1. **Preismodell:** Einmalzahlung, Abo, oder kostenlos?
2. **Support:** Self-Service oder dedizierter Support?
3. **Updates:** Wie oft? Major-Releases vs. Patches?

---

## 📞 Nächste Schritte

### Diese Woche
1. **Raphael:** SketchUp-Plugin Proof-of-Concept starten
   - Einfache Excel-Vorlage erstellen (5 Parameter)
   - Erste 3D-Box generieren
   - JSON exportieren

2. **iMOPS-Team:** Xcode-Projekt aufsetzen
   - Core Data Model skizzieren
   - JSON-Import-Test schreiben
   - Erste SwiftUI View (Baustellenliste)

3. **Gemeinsam:** JSON-Schema finalisieren
   - Video-Call: JSON-Struktur durchgehen
   - Beispiel-Datei mit 1 Testbaustelle
   - GitHub-Repository aufsetzen

### Nächsten Monat
- Wöchentliche Sync-Meetings (30 Min)
- Erste Integration testen (SketchUp → iMOPS)
- Feedback-Runde mit potenziellem Piloten

---

**Viel Erfolg bei der Umsetzung! 🏗️💪**
