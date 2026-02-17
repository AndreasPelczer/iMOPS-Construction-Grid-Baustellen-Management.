# 🎯 RAPHAEL: Aufgaben & Deadlines - SketchUp-Plugin Prototyp

## 👤 Auftraggeber: Andreas Pelczer (iMOPS-Team)
## 📅 Erstellungsdatum: 2026-02-17
## ⏰ Prototyp-Deadline: **2026-02-24 (7 Tage)**

---

## 🎬 Mission

**Erstelle einen funktionsfähigen SketchUp-Plugin-Prototyp**, der:
1. ✅ CSV-Dateien mit Baustellenparametern einliest
2. ✅ Automatisch 3D-Baustellen-Layouts generiert
3. ✅ JSON-Export für iMOPS-Integration ermöglicht

**Erfolgs-Kriterium:** Ende-zu-Ende Demo funktioniert (CSV → 3D → JSON)

---

## 📋 Aufgaben-Übersicht

| # | Aufgabe | Priorität | Zeitaufwand | Deadline | Status |
|---|---------|-----------|-------------|----------|--------|
| 1 | Setup & Starter-Code testen | 🔴 Kritisch | 2h | 18.02.2026 | ⏳ Offen |
| 2 | CSV-Import implementieren | 🔴 Kritisch | 6-8h | 20.02.2026 | ⏳ Offen |
| 3 | 3D-Generierung optimieren | 🟡 Hoch | 8-10h | 22.02.2026 | ⏳ Offen |
| 4 | JSON-Export fertigstellen | 🟢 Mittel | 4-6h | 23.02.2026 | ⏳ Offen |
| 5 | Testing & Demo vorbereiten | 🟢 Mittel | 4h | 24.02.2026 | ⏳ Offen |

**Gesamt-Zeitaufwand:** 24-30 Stunden → **~4-5 Tage Vollzeit** oder **1 Woche Teilzeit**

---

## 🚀 Aufgabe 1: Setup & Starter-Code testen

### ⏰ Deadline: **Heute (18.02.2026, 20:00 Uhr)**
### ⏱️ Zeitaufwand: 2 Stunden

### Was zu tun ist:

#### 1.1 Repository klonen
```bash
git clone https://github.com/AndreasPelczer/iMOPS-Construction-Grid-Baustellen-Management.git
cd iMOPS-Construction-Grid-Baustellen-Management
```

#### 1.2 Plugin installieren
```bash
# Mac:
cp sketchup-plugin/construction_grid.rb ~/Library/Application\ Support/SketchUp\ 2024/SketchUp/Plugins/

# Windows:
copy sketchup-plugin\construction_grid.rb %APPDATA%\SketchUp\SketchUp 2024\Plugins\
```

#### 1.3 SketchUp starten & testen
- SketchUp öffnen
- Menü: `Plugins` → `Construction Grid`
- Sollte 3 Einträge zeigen:
  - ✅ "📥 CSV Importieren"
  - ✅ "📤 JSON Exportieren"
  - ✅ "ℹ️ Über"

#### 1.4 Erste Test-Imports
- Menü: `Plugins` → `Construction Grid` → `CSV Importieren`
- Datei auswählen: `templates/baustelle_vorlage.csv`
- **Erwartetes Ergebnis:** 3D-Zonen erscheinen (noch nicht perfekt)

### ✅ Definition of Done:
- [ ] Repository geklont
- [ ] Plugin in SketchUp-Menü sichtbar
- [ ] Erster CSV-Import funktioniert (auch wenn noch Bugs)
- [ ] Screenshot von 3D-Ausgabe gemacht
- [ ] **Feedback an Andreas:** "Setup funktioniert!" (per Slack/Mail/GitHub Issue)

---

## 🔧 Aufgabe 2: CSV-Import implementieren

### ⏰ Deadline: **20.02.2026, 18:00 Uhr**
### ⏱️ Zeitaufwand: 6-8 Stunden

### Was zu tun ist:

#### 2.1 CSV-Parsing verbessern
**Aktuelle Schwachstellen beheben:**
- ✅ Umlaute korrekt lesen (ä, ö, ü)
- ✅ Verschiedene Spalten-Namen unterstützen (mit/ohne Bindestriche)
- ✅ Leere Zeilen ignorieren
- ✅ Bessere Fehler-Meldungen bei ungültigen Werten

**Code-Stelle:** `sketchup-plugin/construction_grid.rb`, Methode `parse_csv`

**Test-Fälle:**
```ruby
# Teste mit:
# 1. templates/baustelle_vorlage.csv (10 Zonen)
# 2. Eigene CSV mit nur 2 Zonen
# 3. CSV mit absichtlichen Fehlern (fehlende Spalten)
```

#### 2.2 Validierung hinzufügen
**Prüfungen implementieren:**
```ruby
def validate_zone(zone)
  errors = []

  # Pflichtfelder
  errors << "Name fehlt" if zone[:name].nil? || zone[:name].empty?
  errors << "X-Position ungültig" if zone[:x].nil? || zone[:x] < 0
  errors << "Y-Position ungültig" if zone[:y].nil? || zone[:y] < 0
  errors << "Breite muss > 0 sein" if zone[:width] <= 0
  errors << "Höhe muss > 0 sein" if zone[:height] <= 0

  # Risiko-Level gültig?
  valid_risks = ['sicher', 'niedrig', 'mittel', 'hoch', 'sehr-hoch']
  unless valid_risks.include?(zone[:risk_level].downcase)
    errors << "Risiko-Level '#{zone[:risk_level]}' ungültig"
  end

  errors
end
```

**Fehler-Handling:**
- Bei Fehler: Dialog mit klarer Fehlermeldung
- Zeile X in CSV nennen
- Vorschlag zur Behebung geben

#### 2.3 Excel-Support (optional, nur wenn Zeit)
**Falls du RubyXL gem verwenden willst:**
```ruby
# Alternative zu CSV für .xlsx-Dateien
require 'rubyXL'

def parse_excel(file_path)
  workbook = RubyXL::Parser.parse(file_path)
  worksheet = workbook[0]
  # ... (ähnlich wie CSV-Parsing)
end
```

**Entscheidung:** CSV reicht für Prototyp! Excel = Nice-to-have.

### ✅ Definition of Done:
- [ ] CSV-Import funktioniert mit allen 10 Zonen aus Vorlage
- [ ] Validierung zeigt klare Fehler bei ungültigen Daten
- [ ] Mindestens 3 Test-CSVs erstellt und getestet
- [ ] Code kommentiert (Deutsch oder Englisch)
- [ ] **Git-Commit:** "CSV-Import verbessert + Validierung"

---

## 🎨 Aufgabe 3: 3D-Generierung optimieren

### ⏰ Deadline: **22.02.2026, 18:00 Uhr**
### ⏱️ Zeitaufwand: 8-10 Stunden

### Was zu tun ist:

#### 3.1 Zonen-Darstellung verbessern
**Aktuelle Probleme lösen:**

1. **Zonen-Höhe:** Nicht nach Risiko, sondern gleich hoch
   ```ruby
   # ÄNDERN: Alle Zonen 3m hoch (außer Spezialzonen)
   def get_extrusion_height(risk_level)
     3.m  # Konstant für Prototyp
   end
   ```

2. **Text-Labels:** 3D-Text ist zu komplex
   ```ruby
   # VEREINFACHEN: 2D-Text über Zone
   def add_zone_label(entities, zone, x, y, width, height, extrusion_height)
     center_x = x + (width / 2)
     center_y = y + (height / 2)
     center_z = extrusion_height + 0.5.m

     text = entities.add_text(zone[:name], [center_x, center_y, center_z])
     text.arrow_type = Sketchup::Text::ARROW_NONE
   end
   ```

3. **Transparenz:** Zonen sind zu opak
   ```ruby
   # Farbe mit Transparenz (Alpha-Kanal)
   def get_risk_color(risk_level)
     case risk_level.to_s.downcase
     when 'hoch'
       color = Sketchup::Color.new(255, 150, 50)
       color.alpha = 0.7  # 70% Deckkraft
       color
     # ...
     end
   end
   ```

#### 3.2 Grundriss-Ebene automatisch skalieren
**Problem:** Baustelle kann größer/kleiner als 100m × 100m sein

**Lösung:**
```ruby
def draw_ground_plane(entities, zones)
  # Baustellengröße aus Zonen berechnen
  max_x = zones.map { |z| z[:x] + z[:width] }.max + 10.m
  max_y = zones.map { |z| z[:y] + z[:height] }.max + 10.m

  points = [
    [-5.m, -5.m, 0],
    [max_x, -5.m, 0],
    [max_x, max_y, 0],
    [-5.m, max_y, 0]
  ]

  face = entities.add_face(points)
  face.material = Sketchup::Color.new(200, 200, 200)
end
```

#### 3.3 Überlappungs-Warnung (optional)
**Nice-to-have:** Zeige Warnung wenn Zonen sich überlappen
```ruby
def check_overlaps(zones)
  overlaps = []

  zones.each_with_index do |zone1, i|
    zones[i+1..-1].each do |zone2|
      if zones_overlap?(zone1, zone2)
        overlaps << "#{zone1[:name]} überschneidet #{zone2[:name]}"
      end
    end
  end

  if overlaps.any?
    UI.messagebox("⚠️ Überlappungen gefunden:\n#{overlaps.join("\n")}", MB_OK)
  end
end

def zones_overlap?(z1, z2)
  # Rechteck-Kollisions-Check
  !(z1[:x] + z1[:width] < z2[:x] ||
    z2[:x] + z2[:width] < z1[:x] ||
    z1[:y] + z1[:height] < z2[:y] ||
    z2[:y] + z2[:height] < z1[:y])
end
```

#### 3.4 Legende/Maßstab hinzufügen
**Hilfe für Benutzer:**
```ruby
def add_legend(entities)
  # Legende in Ecke platzieren
  legend_x = -10.m
  legend_y = 0.m

  risk_levels = [
    { name: "Sicher", color: get_risk_color('sicher') },
    { name: "Niedrig", color: get_risk_color('niedrig') },
    { name: "Mittel", color: get_risk_color('mittel') },
    { name: "Hoch", color: get_risk_color('hoch') },
    { name: "Sehr Hoch", color: get_risk_color('sehr-hoch') }
  ]

  risk_levels.each_with_index do |level, i|
    y_offset = i * 3.m

    # Farbbox
    points = [
      [legend_x, legend_y + y_offset, 0],
      [legend_x + 2.m, legend_y + y_offset, 0],
      [legend_x + 2.m, legend_y + y_offset + 2.m, 0],
      [legend_x, legend_y + y_offset + 2.m, 0]
    ]
    face = entities.add_face(points)
    face.material = level[:color]

    # Text
    entities.add_text(level[:name], [legend_x + 3.m, legend_y + y_offset + 1.m, 0])
  end
end
```

### ✅ Definition of Done:
- [ ] Alle Zonen werden korrekt in 3D dargestellt
- [ ] Farben entsprechen Risiko-Leveln
- [ ] Text-Labels sind lesbar
- [ ] Grundriss passt sich an Baustellengröße an
- [ ] Legende vorhanden (optional)
- [ ] Überlappungs-Warnung funktioniert (optional)
- [ ] **Git-Commit:** "3D-Generierung optimiert"

---

## 📤 Aufgabe 4: JSON-Export fertigstellen

### ⏰ Deadline: **23.02.2026, 18:00 Uhr**
### ⏱️ Zeitaufwand: 4-6 Stunden

### Was zu tun ist:

#### 4.1 SketchUp-Modell analysieren
**Problem:** Aktuell sind Dummy-Daten im JSON

**Lösung:** Geometrie aus SketchUp extrahieren
```ruby
def extract_zones_from_model
  model = Sketchup.active_model
  entities = model.active_entities

  zones = []

  # Alle Faces durchgehen
  entities.each do |entity|
    next unless entity.is_a?(Sketchup::Face)

    # Zone-Daten aus Geometrie extrahieren
    bounds = entity.bounds

    zone = {
      id: "ZONE-#{zones.length + 1}",
      name: entity.get_attribute('construction_grid', 'name') || "Zone #{zones.length + 1}",
      type: "construction_area",
      risk_level: entity.get_attribute('construction_grid', 'risk_level') || "mittel",
      geometry: {
        type: "polygon",
        coordinates: face_to_coordinates(entity)
      }
    }

    zones << zone
  end

  zones
end

def face_to_coordinates(face)
  face.outer_loop.vertices.map { |v| [v.position.x.to_m, v.position.y.to_m, v.position.z.to_m] }
end
```

#### 4.2 Metadaten speichern
**Beim 3D-Generieren Daten an Geometrie anhängen:**
```ruby
def draw_zone_box(entities, zone)
  # ... (wie vorher)

  face = entities.add_face(points)

  # WICHTIG: Metadaten speichern für späteren Export
  face.set_attribute('construction_grid', 'name', zone[:name])
  face.set_attribute('construction_grid', 'risk_level', zone[:risk_level])
  face.set_attribute('construction_grid', 'ppe', zone[:ppe])
  face.set_attribute('construction_grid', 'access_restriction', zone[:access_restriction])

  # ... (Rest wie vorher)
end
```

#### 4.3 JSON-Format gemäß Spezifikation
**Siehe `IMPLEMENTATION_PLAN.md` Seite mit JSON-Schema:**
```ruby
def export_json
  zones = extract_zones_from_model

  json_data = {
    version: "1.0",
    constructionSite: {
      id: "CS-#{Time.now.strftime('%Y%m%d-%H%M')}",
      name: UI.inputbox(["Baustellenname:"], ["Meine Baustelle"], "Baustelle benennen")[0],
      generated_at: Time.now.iso8601,
      generator: "SketchUp Plugin v#{VERSION}",
      zones: zones.map { |z| format_zone_for_imops(z) }
    }
  }

  save_path = UI.savepanel("JSON exportieren", "", "baustelle.json")
  return unless save_path

  File.write(save_path, JSON.pretty_generate(json_data))
  UI.messagebox("✅ JSON exportiert: #{save_path}\n#{zones.length} Zonen")
end

def format_zone_for_imops(zone)
  {
    id: zone[:id],
    name: zone[:name],
    type: "construction_area",
    safetyLevel: map_risk_to_safety_level(zone[:risk_level]),
    geometry: zone[:geometry],
    requiredPPE: parse_ppe(zone[:ppe]),
    accessRestrictions: [zone[:access_restriction]].compact,
    complianceRules: get_compliance_rules(zone[:risk_level])
  }
end

def map_risk_to_safety_level(risk_level)
  case risk_level.downcase
  when 'sehr-hoch' then 'critical_risk'
  when 'hoch' then 'high_risk'
  when 'mittel' then 'medium_risk'
  when 'niedrig' then 'low_risk'
  when 'sicher' then 'safe'
  else 'unknown'
  end
end

def parse_ppe(ppe_string)
  return [] if ppe_string.nil? || ppe_string.empty?

  # "Helm|Sicherheitsschuhe|Warnweste" → ["hard_hat", "safety_boots", "high_vis_vest"]
  mapping = {
    'Helm' => 'hard_hat',
    'Sicherheitsschuhe' => 'safety_boots',
    'Warnweste' => 'high_vis_vest',
    'Auffanggurt' => 'safety_harness',
    'Gehörschutz' => 'ear_protection',
    'Atemschutz' => 'respirator',
    'Chemikalienschutz' => 'chemical_suit'
  }

  ppe_string.split('|').map { |item| mapping[item.strip] || item.strip.downcase.gsub(' ', '_') }
end

def get_compliance_rules(risk_level)
  # Placeholder - später von iMOPS definiert
  case risk_level.downcase
  when 'sehr-hoch', 'hoch'
    ['BAU-SCP-01', 'DGUV-38-§12']
  when 'mittel'
    ['BAU-SCP-01']
  else
    []
  end
end
```

### ✅ Definition of Done:
- [ ] JSON-Export extrahiert echte Daten aus SketchUp
- [ ] Format entspricht IMPLEMENTATION_PLAN.md
- [ ] Metadaten (PSA, Zugangs-Beschränkungen) enthalten
- [ ] JSON ist valide (mit JSON-Validator testen)
- [ ] **Beispiel-JSON** an iMOPS-Team geschickt (Andreas)
- [ ] **Git-Commit:** "JSON-Export implementiert"

---

## 🧪 Aufgabe 5: Testing & Demo vorbereiten

### ⏰ Deadline: **24.02.2026, 18:00 Uhr**
### ⏱️ Zeitaufwand: 4 Stunden

### Was zu tun ist:

#### 5.1 Test-Fälle durchlaufen
**Mindestens 5 verschiedene Szenarien testen:**

| # | Szenario | Erwartetes Ergebnis |
|---|----------|---------------------|
| 1 | `baustelle_vorlage.csv` (10 Zonen) | Alle Zonen korrekt in 3D |
| 2 | Kleine Baustelle (2 Zonen) | Funktioniert auch bei wenigen Zonen |
| 3 | Große Baustelle (20+ Zonen) | Performance OK, keine Abstürze |
| 4 | Ungültige CSV (fehlende Spalten) | Klare Fehlermeldung |
| 5 | Überlappende Zonen | Warnung erscheint (falls implementiert) |

#### 5.2 Dokumentation schreiben
**Erstelle `sketchup-plugin/README.md`:**
```markdown
# SketchUp Plugin - Installation & Nutzung

## Installation
1. Datei `construction_grid.rb` kopieren nach:
   - Windows: `C:\Users\[Name]\AppData\Roaming\SketchUp\SketchUp 2024\Plugins\`
   - Mac: `~/Library/Application Support/SketchUp 2024/SketchUp/Plugins/`

2. SketchUp neu starten

## Verwendung
1. CSV-Vorlage ausfüllen (`templates/baustelle_vorlage.csv`)
2. SketchUp öffnen
3. Menü: Plugins → Construction Grid → CSV Importieren
4. CSV-Datei auswählen
5. 3D-Modell wird automatisch generiert
6. Menü: Plugins → Construction Grid → JSON Exportieren
7. JSON an iMOPS-App übergeben

## Troubleshooting
- **Plugin erscheint nicht im Menü:** SketchUp wirklich neu gestartet?
- **CSV-Import schlägt fehl:** Alle Pflichtfelder ausgefüllt?
- **Zonen falsch positioniert:** X/Y-Koordinaten prüfen (0,0 = Südwest-Ecke)
```

#### 5.3 Demo-Video aufnehmen (optional)
**5-Minuten-Screencast:**
1. SketchUp starten
2. CSV-Import demonstrieren
3. 3D-Ergebnis zeigen
4. JSON-Export
5. JSON-Datei öffnen (Texteditor)

**Tools:** OBS Studio (kostenlos), QuickTime (Mac), Windows Game Bar

#### 5.4 Beispiel-Baustellen erstellen
**3 vorgefertigte CSVs für verschiedene Use-Cases:**

**A) Kleine Baustelle (Einfamilienhaus):**
```csv
Zonen-Name,X-Position,Y-Position,Breite,Höhe,Risiko-Level,Erforderliche-PSA,Zugangs-Beschränkung
Baugrube,5,5,10,8,hoch,"Helm|Sicherheitsschuhe|Auffanggurt",Bagger-Schein
Lagerplatz,20,5,8,6,niedrig,"Helm|Sicherheitsschuhe",Keine
Parkplatz,30,2,12,8,niedrig,"Warnweste",Keine
```

**B) Mittlere Baustelle (Gewerbe):**
→ Vorlage `baustelle_vorlage.csv` (bereits vorhanden)

**C) Große Baustelle (Hochhaus):**
→ 15-20 Zonen, mehrere Krane, Hochrisiko-Bereiche

### ✅ Definition of Done:
- [ ] Alle 5 Test-Szenarien erfolgreich
- [ ] Plugin-README.md geschrieben
- [ ] 3 Beispiel-CSVs erstellt
- [ ] Demo-Video aufgenommen (optional)
- [ ] Screenshots von allen 3 Beispielen gemacht
- [ ] **Git-Commit:** "Testing & Dokumentation abgeschlossen"
- [ ] **Final Push:** Code auf GitHub

---

## 📊 Erfolgs-Metriken

**Der Prototyp ist fertig, wenn:**

✅ **Funktional:**
- [ ] CSV mit 10 Zonen → 3D-Modell in < 5 Sekunden
- [ ] JSON-Export funktioniert und ist iMOPS-kompatibel
- [ ] Keine Crashes bei normaler Nutzung

✅ **Qualität:**
- [ ] Code ist kommentiert (mind. jede Methode)
- [ ] README.md erklärt Installation + Nutzung
- [ ] Mindestens 3 Test-Baustellen funktionieren

✅ **Kommunikation:**
- [ ] Andreas hat Beispiel-JSON erhalten
- [ ] Git-Commits sind sinnvoll benannt
- [ ] GitHub Repository ist aktuell

---

## 📞 Support & Kommunikation

### Daily Stand-up (empfohlen)
**Täglich um 18:00 Uhr:**
- 5-Minuten-Update an Andreas (Slack/Mail)
- Format: "Heute geschafft: X / Morgen geplant: Y / Blocker: Z"

### Bei Problemen
**Sofort melden (nicht erst am Ende!):**
- 🔴 **Kritisch (< 2h):** SketchUp-API funktioniert nicht wie erwartet
- 🟡 **Mittel (< 1 Tag):** Unklare Anforderungen im JSON-Format
- 🟢 **Niedrig:** Fragen zu Best Practices

**Kontakt:**
- GitHub Issues: [Link zum Repo Issues]
- Slack: #construction-grid-dev (falls vorhanden)
- Mail: [Andreas E-Mail]

---

## 🎁 Bonus-Aufgaben (nur wenn Zeit übrig!)

### Wenn alles vor Deadline fertig ist:

#### Bonus 1: Ausrüstung (Krane, Container)
- CSV-Import für `baustelle_equipment.csv`
- Krane als 3D-Symbole (Kegel oder einfaches Modell)
- Sicherheitsradius visualisieren

#### Bonus 2: Zufahrten & Tore
- CSV-Import für `baustelle_zufahrten.csv`
- Tore als farbige Linien im Grundriss
- Pfeile für Fahrtrichtung

#### Bonus 3: Excel-Support (.xlsx)
- RubyXL gem verwenden
- Gleiche Logik wie CSV, nur anderer Parser

#### Bonus 4: UI-Verbesserungen
- Fortschrittsbalken beim Import
- Vorschau-Dialog vor 3D-Generierung
- "Rückgängig"-Button

**→ Aber: Prototyp-Scope nicht überladen! Lieber solid als fancy.**

---

## 📅 Zeitplan-Übersicht

```
17.02. (Mo)  │ [========] Starter-Code testen (2h)
18.02. (Di)  │ [=================] CSV-Import (6h)
19.02. (Mi)  │ [=================] CSV-Import fertig (2h)
             │ [=================] 3D-Generierung (4h)
20.02. (Do)  │ [=================] 3D-Generierung fertig (6h)
21.02. (Fr)  │ [=================] JSON-Export (6h)
22.02. (Sa)  │ [=================] Testing (4h)
23.02. (So)  │ [====] Puffer + Doku (2h)
24.02. (Mo)  │ [🎉] DEMO-TAG!
```

**Total:** 26-28 Stunden über 7 Tage

---

## ✅ Finale Checkliste (vor Demo)

- [ ] Code committed + gepusht auf GitHub
- [ ] Alle TODO-Kommentare entfernt oder bearbeitet
- [ ] README.md aktualisiert
- [ ] Beispiel-JSONs im Repo (`examples/` Ordner)
- [ ] Screenshots im Repo (`docs/screenshots/`)
- [ ] Demo-Szenario vorbereitet (5 Min Präsentation)
- [ ] **GitHub Issue erstellt:** "Prototyp fertig - bereit für Review"

---

## 🎬 Demo-Tag (24.02.2026)

### Was du präsentierst:

**Live-Demo (5-7 Minuten):**
1. **Setup zeigen** (30 Sek)
   - "So installiert man das Plugin"

2. **CSV-Import** (1 Min)
   - Excel-Vorlage zeigen
   - Import-Dialog
   - 3D-Generierung

3. **3D-Ergebnis** (2 Min)
   - Durch Modell navigieren
   - Farben erklären
   - Legende zeigen

4. **JSON-Export** (1 Min)
   - Export-Dialog
   - JSON-Datei öffnen
   - Struktur erklären

5. **Integration (Ausblick)** (2 Min)
   - "Dieses JSON geht jetzt an iMOPS-App"
   - Nächste Schritte besprechen

**Q&A:** 5-10 Minuten für Fragen

---

## 🏆 Erfolg!

**Wenn du diese Aufgaben abgeschlossen hast:**
→ Du hast ein funktionierendes SketchUp-Plugin gebaut!
→ iMOPS-Integration kann beginnen!
→ Proof-of-Concept ist validiert!

**Danke für deine Arbeit, Raphael! 🚀🏗️**

---

**Viel Erfolg! Bei Fragen: Sofort melden, nicht warten! 💪**
