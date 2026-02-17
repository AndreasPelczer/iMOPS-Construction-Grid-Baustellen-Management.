# ============================================================================
# Construction Grid - SketchUp Plugin
# ============================================================================
# Automatische 3D-Baustellengenerierung aus CSV/Excel-Vorlagen
#
# Author: Raphael (CAD/SketchUp-Experte)
# Version: 0.1.0-prototype
# License: MIT
# ============================================================================

require 'sketchup.rb'
require 'json'
require 'csv'

module ConstructionGrid

  VERSION = '0.1.0-prototype'

  # ==========================================================================
  # PHASE 1: CSV-Import (RAPHAEL: Start hier!)
  # ==========================================================================

  def self.import_csv
    # TODO (RAPHAEL): CSV-Datei-Dialog öffnen
    # Tipp: UI.openpanel("CSV-Datei auswählen", "", "*.csv")

    csv_path = UI.openpanel("Baustellen-CSV auswählen", "", "CSV Files|*.csv||")
    return unless csv_path

    zones = parse_csv(csv_path)

    if zones.empty?
      UI.messagebox("Keine Zonen gefunden oder CSV-Fehler!")
      return
    end

    generate_3d_model(zones)
    UI.messagebox("✅ Baustelle mit #{zones.length} Zonen generiert!")
  end

  # --------------------------------------------------------------------------
  # CSV-Parser (RAPHAEL: Hier CSV-Logik implementieren)
  # --------------------------------------------------------------------------
  def self.parse_csv(file_path)
    zones = []

    begin
      CSV.foreach(file_path, headers: true, header_converters: :symbol) do |row|
        # CSV-Zeile in Zone-Hash konvertieren
        zone = {
          name: row[:zonen_name] || row[:"zonen-name"],
          x: row[:x_position] || row[:"x-position"].to_f,
          y: row[:y_position] || row[:"y-position"].to_f,
          width: row[:breite].to_f,
          height: row[:höhe].to_f,
          risk_level: row[:risiko_level] || row[:"risiko-level"],
          ppe: row[:erforderliche_psa] || row[:"erforderliche-psa"] || "",
          access_restriction: row[:zugangs_beschränkung] || row[:"zugangs-beschränkung"] || "Keine"
        }

        # Validierung (RAPHAEL: Hier erweitern falls nötig)
        next if zone[:name].nil? || zone[:name].empty?
        next if zone[:x].nil? || zone[:y].nil?
        next if zone[:width] <= 0 || zone[:height] <= 0

        zones << zone
      end
    rescue => e
      UI.messagebox("CSV-Fehler: #{e.message}")
      return []
    end

    zones
  end

  # ==========================================================================
  # PHASE 2: 3D-Generierung (RAPHAEL: Hier 3D-Magie!)
  # ==========================================================================

  def self.generate_3d_model(zones)
    model = Sketchup.active_model
    entities = model.active_entities

    # TODO (RAPHAEL): Optional - Bestehende Geometrie löschen?
    # Vorsicht: Nur wenn gewünscht!
    # entities.clear!

    # Grundriss-Ebene zeichnen (grauer Boden)
    draw_ground_plane(entities)

    # Jede Zone als 3D-Box zeichnen
    zones.each do |zone|
      draw_zone_box(entities, zone)
    end

    # Kamera optimal positionieren
    model.active_view.zoom_extents
  end

  # --------------------------------------------------------------------------
  # Grundriss-Ebene (grauer Boden)
  # --------------------------------------------------------------------------
  def self.draw_ground_plane(entities)
    # TODO (RAPHAEL): Baustellengröße aus CSV berechnen oder hardcoded?
    # Für Prototyp: 100m x 100m Grundfläche

    points = [
      [0, 0, 0],
      [100.m, 0, 0],
      [100.m, 100.m, 0],
      [0, 100.m, 0]
    ]

    face = entities.add_face(points)
    face.material = Sketchup::Color.new(200, 200, 200) # Hellgrau
    face.back_material = face.material
  end

  # --------------------------------------------------------------------------
  # Zone als 3D-Box zeichnen (RAPHAEL: Hier die Magie!)
  # --------------------------------------------------------------------------
  def self.draw_zone_box(entities, zone)
    # 1. Rechteck als Basis zeichnen
    x = zone[:x].m
    y = zone[:y].m
    w = zone[:width].m
    h = zone[:height].m

    points = [
      [x, y, 0.1.m],          # Leicht über Grundebene (0.1m)
      [x + w, y, 0.1.m],
      [x + w, y + h, 0.1.m],
      [x, y + h, 0.1.m]
    ]

    face = entities.add_face(points)

    # 2. Farbe nach Risiko-Level
    color = get_risk_color(zone[:risk_level])
    face.material = color

    # 3. Extrusion (3D-Effekt) - Höhe nach Risiko
    extrusion_height = get_extrusion_height(zone[:risk_level])
    face.pushpull(extrusion_height)

    # 4. Text-Label (Zonen-Name)
    add_zone_label(entities, zone, x, y, w, h, extrusion_height)
  end

  # --------------------------------------------------------------------------
  # Risiko-Level → Farbe (RAPHAEL: Hier Farben anpassen)
  # --------------------------------------------------------------------------
  def self.get_risk_color(risk_level)
    case risk_level.to_s.downcase
    when 'sicher'
      Sketchup::Color.new(100, 150, 255)   # Blau
    when 'niedrig'
      Sketchup::Color.new(100, 255, 100)   # Grün
    when 'mittel'
      Sketchup::Color.new(255, 255, 100)   # Gelb
    when 'hoch'
      Sketchup::Color.new(255, 150, 50)    # Orange
    when 'sehr-hoch', 'sehr_hoch'
      Sketchup::Color.new(255, 50, 50)     # Rot
    else
      Sketchup::Color.new(150, 150, 150)   # Grau (unbekannt)
    end
  end

  # --------------------------------------------------------------------------
  # Risiko-Level → Extrusions-Höhe (höher = gefährlicher)
  # --------------------------------------------------------------------------
  def self.get_extrusion_height(risk_level)
    case risk_level.to_s.downcase
    when 'sicher'
      1.m
    when 'niedrig'
      2.m
    when 'mittel'
      3.m
    when 'hoch'
      4.m
    when 'sehr-hoch', 'sehr_hoch'
      5.m
    else
      2.5.m
    end
  end

  # --------------------------------------------------------------------------
  # Text-Label für Zone (RAPHAEL: 3D-Text oder 2D?)
  # --------------------------------------------------------------------------
  def self.add_zone_label(entities, zone, x, y, width, height, extrusion_height)
    # Text in der Mitte der Zone platzieren
    center_x = x + (width / 2)
    center_y = y + (height / 2)
    center_z = extrusion_height + 0.5.m  # Leicht über der Box

    # 3D-Text erstellen (RAPHAEL: Alternativ 2D-Text möglich)
    text_position = [center_x, center_y, center_z]

    # TODO (RAPHAEL): 3D-Text in SketchUp ist etwas kompliziert
    # Für Prototyp: Einfacher 2D-Text reicht
    # text = entities.add_3d_text(zone[:name], ...)

    # Alternativ: Text-Note (einfacher für Prototyp)
    note = entities.add_text(zone[:name], text_position)
    note.arrow_type = Sketchup::Text::ARROW_NONE
  end

  # ==========================================================================
  # PHASE 3: JSON-Export (RAPHAEL: iMOPS-Schnittstelle)
  # ==========================================================================

  def self.export_json
    # TODO (RAPHAEL): Aktuelle Zonen aus SketchUp-Modell extrahieren
    # Für Prototyp: Dummy-Daten

    zones_data = []

    # SketchUp-Modell durchsuchen (vereinfacht)
    model = Sketchup.active_model
    # TODO: Hier Geometrie analysieren und in zones_data schreiben

    # Dummy für Prototyp
    zones_data = [
      {
        id: "ZONE-001",
        name: "Beispiel-Zone",
        type: "construction_area",
        risk_level: "hoch",
        geometry: {
          type: "polygon",
          coordinates: [[10, 10, 0], [30, 10, 0], [30, 30, 0], [10, 30, 0]]
        },
        required_ppe: ["hard_hat", "safety_boots"],
        access_restrictions: ["qualification_xyz"]
      }
    ]

    json_data = {
      version: "1.0",
      construction_site: {
        id: "CS-PROTOTYPE",
        name: "Prototyp Baustelle",
        generated_at: Time.now.iso8601,
        zones: zones_data
      }
    }

    # Speicher-Dialog
    save_path = UI.savepanel("JSON exportieren", "", "baustelle.json")
    return unless save_path

    File.write(save_path, JSON.pretty_generate(json_data))
    UI.messagebox("✅ JSON exportiert: #{save_path}")
  end

  # ==========================================================================
  # PHASE 4: SketchUp-Menü-Integration
  # ==========================================================================

  unless file_loaded?(__FILE__)
    # Menü-Einträge erstellen
    menu = UI.menu('Plugins')
    submenu = menu.add_submenu('Construction Grid')

    submenu.add_item('📥 CSV Importieren') {
      ConstructionGrid.import_csv
    }

    submenu.add_item('📤 JSON Exportieren') {
      ConstructionGrid.export_json
    }

    submenu.add_separator

    submenu.add_item('ℹ️ Über') {
      UI.messagebox("Construction Grid v#{VERSION}\n\nAutomatische Baustellengenerierung für iMOPS", MB_OK)
    }

    file_loaded(__FILE__)
  end

end

# ============================================================================
# RAPHAEL: QUICK-START ANLEITUNG
# ============================================================================
#
# 1. INSTALLATION:
#    - Diese Datei kopieren nach:
#      Windows: C:\Users\[Name]\AppData\Roaming\SketchUp\SketchUp 2024\Plugins\
#      Mac: ~/Library/Application Support/SketchUp 2024/SketchUp [version]/SketchUp/Plugins/
#
# 2. SKETCHUP NEU STARTEN
#
# 3. TESTEN:
#    - Menü: Plugins → Construction Grid → CSV Importieren
#    - Datei: templates/baustelle_vorlage.csv auswählen
#    - 3D-Modell sollte erscheinen!
#
# 4. NÄCHSTE SCHRITTE:
#    - Siehe RAPHAEL_TASKS.md für detaillierte Aufgaben
#
# ============================================================================
