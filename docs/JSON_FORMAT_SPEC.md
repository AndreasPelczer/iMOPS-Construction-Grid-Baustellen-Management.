# 📋 iMOPS SketchUp Export - JSON-Format Spezifikation

## Übersicht

Dieses Dokument beschreibt das JSON-Format, das vom SketchUp-Plugin exportiert wird. Das Format ist so designt, dass es:

- ✅ **Von iMOPS direkt importiert werden kann** (ohne Konvertierung)
- ✅ **Alle Sicherheits- und Kalkulations-Daten enthält** (vollständig)
- ✅ **Menschenlesbar ist** (für Debugging und manuelle Anpassungen)
- ✅ **Erweiterbar ist** (neue Felder können ohne Breaking Changes hinzugefügt werden)

---

## 📦 Haupt-Struktur

```json
{
  "meta": { ... },           // Metadaten über den Export
  "project": { ... },        // Projekt-Informationen
  "modelInfo": { ... },      // SketchUp-Modell-Statistiken
  "safety": { ... },         // Sicherheits-Daten (Gefahrenzonen, PSA)
  "calculation": { ... },    // Kalkulations-Daten (Bauteile, Kosten)
  "geometry": { ... },       // Geometrie-Daten (optional, für 3D-Visualisierung)
  "tags": { ... },           // Tags/Labels für Filterung
  "exports": { ... },        // Verfügbare Export-Formate
  "checksum": { ... }        // Checksumme zur Validierung
}
```

---

## 1️⃣ Meta (Metadaten)

```json
{
  "meta": {
    "version": "1.0.0",                          // Format-Version (SemVer)
    "exportDate": "2026-02-17T14:32:15Z",        // ISO 8601 Timestamp
    "plugin": "iMOPS SketchUp Plugin",           // Plugin-Name
    "sketchupVersion": "2024",                   // SketchUp-Version
    "exportedBy": "raphael@beispiel.de"          // User-E-Mail
  }
}
```

### Verwendung in iMOPS:
- **version**: Bestimmt, welcher Parser verwendet wird
- **exportDate**: Für Sortierung/Filterung in der App
- **exportedBy**: Audit-Trail, wer hat exportiert

---

## 2️⃣ Project (Projekt-Informationen)

```json
{
  "project": {
    "id": "MHM-2026-001",                        // Eindeutige Projekt-ID
    "name": "Mannheim Gewerbepark",              // Anzeigename
    "client": "Müller GmbH",                     // Bauherr/Auftraggeber
    "location": "Mannheim, Industriestraße 42",  // Standort
    "startDate": "2026-03-01",                   // Projektstart (ISO 8601)
    "endDate": "2026-12-31",                     // Projektende
    "description": "..."                         // Beschreibung
  }
}
```

### Verwendung in iMOPS:
- **id**: Wird für Cloud-Sync verwendet (Update vs. Neu-Import)
- **name**: Haupttitel in der App
- **location**: GPS-Koordinaten können später hinzugefügt werden

---

## 3️⃣ ModelInfo (SketchUp-Modell-Statistiken)

```json
{
  "modelInfo": {
    "totalGroups": 12,                           // Anzahl Gruppen
    "totalComponents": 47,                       // Anzahl Komponenten
    "totalFaces": 156,                           // Anzahl Flächen
    "totalArea": { "value": 1245.5, "unit": "m²" },
    "totalVolume": { "value": 4567.8, "unit": "m³" },
    "boundingBox": {
      "min": { "x": 0.0, "y": 0.0, "z": 0.0 },
      "max": { "x": 45.0, "y": 30.0, "z": 12.5 }
    }
  }
}
```

### Verwendung in iMOPS:
- **Statistiken-Dashboard**: "Dein Projekt hat 1.245 m² Fläche"
- **3D-Viewer**: Bounding Box für Kamera-Initialisierung

---

## 4️⃣ Safety (Sicherheits-Daten) ⚠️

### 4.1 Gefahrenzone (HazardZone)

```json
{
  "safety": {
    "hazardZones": [
      {
        "id": "HZ-001",                          // Eindeutige ID
        "name": "Dachgeschoss",                  // Anzeigename
        "type": "FALL_RISK",                     // Gefahren-Typ (siehe unten)
        "riskLevel": "HIGH",                     // HIGH | MEDIUM | LOW
        "description": "Absturzgefahr...",       // Beschreibung

        "triggers": [                            // Was hat die Erkennung ausgelöst?
          {
            "type": "HEIGHT",                    // Trigger-Typ
            "value": 12.5,                       // Gemessener Wert
            "unit": "m",                         // Einheit
            "threshold": 2.0,                    // Schwellwert
            "triggered": true                    // Wurde ausgelöst?
          }
        ],

        "requiredPPE": [                         // Erforderliche PSA
          {
            "type": "HELMET",                    // PSA-Typ
            "name": "Schutzhelm",                // Anzeigename
            "category": "HEAD_PROTECTION",       // Kategorie
            "mandatory": true,                   // Pflicht?
            "standard": "EN 397"                 // Norm
          }
        ],

        "complianceNotes": [                     // Rechtliche Hinweise
          "§12 ArbSchG: Gefährdungsbeurteilung",
          "TRBS 2121: Absturz"
        ],

        "geometry": {                            // 3D-Geometrie
          "type": "POLYGON",                     // POLYGON | CIRCLE | BOX
          "coordinates": [ ... ],                // Koordinaten
          "area": { "value": 225.0, "unit": "m²" }
        },

        "accessRestriction": {                   // Zugangskontrollen
          "requiresPermit": true,                // Erlaubnisschein nötig?
          "permitType": "HEIGHT_WORK_PERMIT",    // Art des Erlaubnisscheins
          "maxPersons": 4,                       // Max. Personenzahl
          "supervisorRequired": true             // Aufsicht nötig?
        }
      }
    ]
  }
}
```

### 4.2 Gefahren-Typen (type)

| Typ | Beschreibung | Erkennungs-Trigger |
|-----|--------------|-------------------|
| `FALL_RISK` | Absturzgefahr | Höhe > 2m |
| `CONFINED_SPACE` | Enger Raum | Fläche < 15m² |
| `VEHICLE_TRAFFIC` | Fahrzeugverkehr | Komponente: Stapler/LKW |
| `CRANE_OPERATION` | Kran-Betrieb | Komponente: Kran |
| `FIRE_RISK` | Brandgefahr | Tag: "Schweiß", "Elektrik" |
| `ELECTRICAL` | Elektrische Gefahr | Tag: "Elektrik" |
| `CHEMICAL` | Chemische Gefahr | Material: "Lösungsmittel" |
| `NOISE` | Lärm | Komponente: "Kompressor" |

### 4.3 PSA-Typen (requiredPPE.type)

| Typ | Beschreibung | Kategorie |
|-----|--------------|-----------|
| `HELMET` | Schutzhelm | HEAD_PROTECTION |
| `FALL_PROTECTION` | Absturzsicherung | BODY_PROTECTION |
| `SAFETY_HARNESS` | Auffanggurt | BODY_PROTECTION |
| `RESPIRATORY_PROTECTION` | Atemschutz | RESPIRATORY_PROTECTION |
| `GAS_DETECTOR` | Sauerstoffmessgerät | MEASUREMENT_DEVICE |
| `HIGH_VIS_VEST` | Warnweste | VISIBILITY |
| `SAFETY_SHOES` | Sicherheitsschuhe | FOOT_PROTECTION |
| `WELDING_HELMET` | Schweißerhelm | HEAD_PROTECTION |
| `WELDING_GLOVES` | Schweißerhandschuhe | HAND_PROTECTION |
| `FIRE_RESISTANT_CLOTHING` | Schweißerschutzkleidung | BODY_PROTECTION |

---

## 5️⃣ Calculation (Kalkulations-Daten) 💰

### 5.1 Komponente (Component)

```json
{
  "calculation": {
    "components": [
      {
        "id": "COMP-001",                        // Eindeutige ID
        "category": "WALLS",                     // Kategorie (siehe unten)
        "type": "DRYWALL",                       // Typ
        "material": "Gipskartonplatte 2x12,5mm", // Material-Beschreibung
        "description": "Trockenbau-Innenwände",  // Anzeigename

        "quantity": {                            // Menge
          "value": 45.5,
          "unit": "m²"                           // m² | m³ | Stück | m | ...
        },

        "unitPrice": {                           // Einheitspreis
          "value": 28.50,
          "unit": "EUR/m²",
          "source": "Standard-Preisliste 2026"   // Woher kommt der Preis?
        },

        "totalCost": {                           // Gesamt-Kosten
          "value": 1296.75,
          "currency": "EUR"
        },

        "laborHours": {                          // Arbeitszeit
          "value": 18.2,
          "unit": "h",
          "hourlyRate": 45.00                    // EUR/h
        },

        "geometry": {                            // Geometrie-Info
          "groups": ["Erdgeschoss", "1.OG"],     // Wo ist das Bauteil?
          "thickness": { "value": 0.1, "unit": "m" },
          "height": { "value": 2.8, "unit": "m" }
        },

        "lvPosition": {                          // Leistungsverzeichnis
          "number": "352.01.001",                // LV-Position
          "description": "Trockenbau-Wand...",
          "unitOfMeasure": "m²"
        }
      }
    ]
  }
}
```

### 5.2 Kategorien (category)

| Kategorie | Beschreibung | Typische Einheiten |
|-----------|--------------|-------------------|
| `WALLS` | Wände | m² |
| `FLOORS` | Böden/Decken | m² |
| `DOORS` | Türen | Stück |
| `WINDOWS` | Fenster | Stück |
| `SCAFFOLDING` | Gerüste | m² |
| `ROOFING` | Dacharbeiten | m² |
| `ELECTRICAL` | Elektrik | Stück, m |
| `PLUMBING` | Sanitär | Stück, m |
| `HVAC` | Heizung/Lüftung | Stück |
| `FINISHES` | Oberflächen | m² |

### 5.3 Zusammenfassung (summary)

```json
{
  "calculation": {
    "summary": {
      "totalComponents": 5,                      // Anzahl Bauteile
      "totalCost": {
        "materials": 32826.75,                   // Material-Kosten
        "labor": 7185.00,                        // Lohn-Kosten
        "total": 40011.75,                       // Gesamt
        "currency": "EUR"
      },
      "totalLaborHours": 94.2,                   // Gesamt-Arbeitsstunden
      "costByCategory": [                        // Kosten nach Kategorie
        { "category": "WALLS", "cost": 1296.75, "percentage": 3.2 },
        { "category": "FLOORS", "cost": 10200.00, "percentage": 25.5 }
      ],
      "estimatedDuration": {                     // Geschätzte Dauer
        "value": 6,
        "unit": "Monate"
      }
    }
  }
}
```

---

## 6️⃣ Geometry (Geometrie-Daten) 📐

### 6.1 Gebäude-Struktur

```json
{
  "geometry": {
    "buildings": [
      {
        "id": "BLDG-001",
        "name": "Hauptgebäude",
        "floors": [
          {
            "id": "FLOOR-001",
            "name": "Erdgeschoss",
            "elevation": 0.0,                    // Höhe über Grund
            "height": 3.0,                       // Geschosshöhe
            "area": { "value": 450.0, "unit": "m²" },
            "groups": [                          // Räume/Gruppen
              { "name": "Büro 1", "area": 25.0 },
              { "name": "Büro 2", "area": 25.0 }
            ]
          }
        ]
      }
    ],

    "siteLayout": {                              // Baustellenplan
      "totalSiteArea": { "value": 2500.0, "unit": "m²" },
      "buildingFootprint": { "value": 450.0, "unit": "m²" },
      "parkingArea": { "value": 300.0, "unit": "m²" },
      "greenArea": { "value": 800.0, "unit": "m²" },
      "roadArea": { "value": 950.0, "unit": "m²" }
    }
  }
}
```

### 6.2 Geometrie-Typen (für Gefahrenzonen)

#### POLYGON (Vieleck)
```json
{
  "type": "POLYGON",
  "coordinates": [
    { "x": 10.0, "y": 15.0, "z": 12.5 },
    { "x": 25.0, "y": 15.0, "z": 12.5 },
    { "x": 25.0, "y": 30.0, "z": 12.5 },
    { "x": 10.0, "y": 30.0, "z": 12.5 }
  ],
  "area": { "value": 225.0, "unit": "m²" }
}
```

#### CIRCLE (Kreis)
```json
{
  "type": "CIRCLE",
  "center": { "x": 20.0, "y": 20.0, "z": 0.0 },
  "radius": 40.0,
  "safetyRadius": 10.0,                          // Zusätzlicher Sicherheitsabstand
  "area": { "value": 5026.5, "unit": "m²" }
}
```

#### BOX (Quader)
```json
{
  "type": "BOX",
  "min": { "x": 5.0, "y": 8.0, "z": 0.0 },
  "max": { "x": 10.0, "y": 12.0, "z": 3.0 },
  "volume": { "value": 60.0, "unit": "m³" }
}
```

---

## 7️⃣ Tags (Tags/Labels)

```json
{
  "tags": {
    "trades": [                                  // Gewerke
      "Rohbau",
      "Trockenbau",
      "Elektrik",
      "Sanitär"
    ],
    "phases": [                                  // Bauphasen
      "Planung",
      "Rohbau",
      "Ausbau",
      "Fertigstellung"
    ]
  }
}
```

### Verwendung in iMOPS:
- **Filter**: "Zeige nur Elektrik-Gefahrenzonen"
- **Statistiken**: "Wie viele Rohbau-Komponenten gibt es?"

---

## 8️⃣ Exports (Verfügbare Export-Formate)

```json
{
  "exports": {
    "pdf": {
      "available": false,                        // Wurde PDF exportiert?
      "formats": ["A4", "A3"]                    // Verfügbare Formate
    },
    "csv": {
      "available": false,
      "includes": ["components", "costs", "hazards"]
    },
    "ifc": {
      "available": false,                        // BIM-Format (optional)
      "version": "IFC4"
    }
  }
}
```

---

## 9️⃣ Checksum (Validierung)

```json
{
  "checksum": {
    "algorithm": "SHA256",
    "value": "a3c7e9b2f1d4e8a6c5b3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8a7b6c5d4e3f2a1"
  }
}
```

### Verwendung:
- **Integritäts-Check**: Datei wurde nicht manipuliert
- **Cloud-Sync**: Erkennt Änderungen

---

## 🔄 Versionierung

### Format-Versionen

| Version | Release | Änderungen |
|---------|---------|------------|
| `1.0.0` | 2026-02 | Initial Release |
| `1.1.0` | TBD | + IFC-Support, + GPS-Koordinaten |
| `2.0.0` | TBD | Breaking Changes (falls nötig) |

### Abwärtskompatibilität

- **Minor-Updates** (z.B. 1.0 → 1.1): Neue Felder hinzugefügt, alte bleiben erhalten
- **Major-Updates** (z.B. 1.x → 2.0): Breaking Changes, alte Formate werden nicht mehr unterstützt

---

## 📖 Beispiel-Anwendungsfälle

### Use Case 1: Gefahrenzonen in iMOPS anzeigen

```javascript
// iMOPS-App liest JSON
const data = JSON.parse(exportFile);

// Iteriere über Gefahrenzonen
data.safety.hazardZones.forEach(zone => {
  // Zeige auf 3D-Karte
  map.addHazardZone({
    name: zone.name,
    type: zone.type,
    riskLevel: zone.riskLevel,
    geometry: zone.geometry,
    requiredPPE: zone.requiredPPE.map(ppe => ppe.name)
  });

  // Erstelle Check-In-Regel
  if (zone.accessRestriction.requiresPermit) {
    createCheckInRule({
      zone: zone.id,
      permitType: zone.accessRestriction.permitType,
      maxPersons: zone.accessRestriction.maxPersons
    });
  }
});
```

### Use Case 2: Kosten-Schätzung anzeigen

```javascript
// Zeige Kosten-Zusammenfassung
const summary = data.calculation.summary;

console.log(`Gesamt-Kosten: ${summary.totalCost.total} ${summary.totalCost.currency}`);
console.log(`Material: ${summary.totalCost.materials} EUR`);
console.log(`Lohn: ${summary.totalCost.labor} EUR`);

// Top-3 teuerste Kategorien
const topCategories = summary.costByCategory
  .sort((a, b) => b.cost - a.cost)
  .slice(0, 3);

topCategories.forEach(cat => {
  console.log(`${cat.category}: ${cat.cost} EUR (${cat.percentage}%)`);
});
```

### Use Case 3: PSA-Anforderungen für Mitarbeiter

```javascript
// Mitarbeiter checkt in Zone "Dachgeschoss" ein
const zone = data.safety.hazardZones.find(z => z.name === "Dachgeschoss");

// Zeige PSA-Anforderungen
const ppe = zone.requiredPPE.filter(p => p.mandatory);

showAlert({
  title: `Gefahrenzone: ${zone.name}`,
  message: `Risiko-Level: ${zone.riskLevel}`,
  ppe: ppe.map(p => `• ${p.name} (${p.standard})`).join('\n'),
  action: "Check-In bestätigen"
});
```

---

## 🧪 Validierung

### JSON-Schema (optional)

Für automatische Validierung kann ein JSON-Schema verwendet werden:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "iMOPS SketchUp Export",
  "type": "object",
  "required": ["meta", "project", "safety", "calculation"],
  "properties": {
    "meta": { "$ref": "#/definitions/Meta" },
    "project": { "$ref": "#/definitions/Project" },
    "safety": { "$ref": "#/definitions/Safety" },
    "calculation": { "$ref": "#/definitions/Calculation" }
  }
}
```

### Beispiel-Validierung

```bash
# Validiere JSON-Datei
npm install -g ajv-cli
ajv validate -s schema.json -d export.json
```

---

## 📊 Datengröße

### Typische Dateigrößen

| Projekt-Größe | Komponenten | Gefahrenzonen | Dateigröße |
|---------------|-------------|---------------|-----------|
| Klein | 20-50 | 2-5 | 50-100 KB |
| Mittel | 100-200 | 5-15 | 150-300 KB |
| Groß | 500+ | 20+ | 500 KB - 1 MB |

### Optimierungen

- **Koordinaten runden**: `12.345678` → `12.35` (spart 40%)
- **Redundante Felder entfernen**: z.B. `totalCost` kann berechnet werden
- **GZIP-Kompression**: Reduziert Dateigröße um ~70%

---

## 🔐 Sicherheit

### Sensible Daten

**Sollten NICHT im Export enthalten sein:**
- ❌ Passwörter / API-Tokens
- ❌ Persönliche Mitarbeiter-Daten (Namen, Adressen)
- ❌ Finanzielle Details (exakte Preislisten, Gewinnmargen)

**Können enthalten sein:**
- ✅ Projekt-Name, Standort
- ✅ Aggregierte Kosten-Schätzungen
- ✅ Gefahrenzonen, PSA-Anforderungen
- ✅ Geometrie-Daten

---

## 📝 Lizenz & Nutzung

- **Format-Lizenz**: MIT (frei verwendbar)
- **Plugin-Lizenz**: Proprietär (iMOPS)
- **Daten-Eigentum**: Gehört dem User (Raphael)

---

## ❓ FAQ

### F: Kann ich das JSON manuell bearbeiten?
**A:** Ja! Das Format ist bewusst menschenlesbar. Achte darauf, dass die JSON-Syntax korrekt bleibt.

### F: Kann ich eigene Felder hinzufügen?
**A:** Ja! Unbekannte Felder werden von iMOPS ignoriert. Nutze Präfixe wie `custom_xyz` für eigene Felder.

### F: Wie handle ich Updates?
**A:** Die `project.id` bleibt gleich. iMOPS erkennt das Projekt und fragt, ob es aktualisiert werden soll.

### F: Kann ich mehrere Projekte in einer Datei exportieren?
**A:** Nein, jede Datei enthält genau ein Projekt. Nutze Arrays auf API-Ebene, wenn nötig.

---

**Version:** 1.0.0
**Letzte Aktualisierung:** 2026-02-17
**Kontakt:** support@imops.com
