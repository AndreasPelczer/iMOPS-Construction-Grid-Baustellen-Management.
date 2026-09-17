//
//  VerlegeplanLeser.swift
//  Bogen 2 (Nordstern-Kopf): aus einer DXF-Zeichnung MENGEN ziehen.
//
//  Anders als der WandLeser (Server, Wandlängen aus LINE) ist ein Pflaster-/Flächen-
//  Verlegeplan ganz anders gebaut: jeder Stein ist ein INSERT-Block, das MASS steht im
//  BLOCKNAMEN ("…39x19_5x8cm"), und die LAYER-Namen tragen den Aufbau (Pflaster, Splitt
//  8/16, Schotter 0/32). Das ist dasselbe Muster wie bei Raffis IFC: „die Namen tragen
//  alles". Deshalb ein schlanker, OFFLINE Swift-Leser — kein Backend, sofort testbar.
//
//  EHRLICH (Tao): die Fläche kommt aus der Steinzählung × Maß im Namen (netto, ohne
//  Fugenzuschlag) — ein Nachweis aus der Zeichnung, keine Schätzung. Wo ein Maß fehlt,
//  wird gezählt (Stück), nicht geraten. Aufbau-Layer ohne eigene Geometrie werden als
//  Hinweis gemeldet, nicht heimlich mit einer erfundenen Menge gefüllt.
//

import Foundation

// MARK: - Ergebnis

/// Ein erkannter Layer des Verlegeplans, als fertige LV-Menge (Fläche oder Stück).
struct VerlegeLayer: Identifiable {
    enum Art { case flaeche, stueck }
    let name: String            // Layer-Name aus der DXF ("Pflaster", "Leistensteine")
    let art: Art
    let menge: Double           // m² (flaeche) oder Stück (stueck)
    let objekte: Int            // Anzahl INSERT-Blöcke auf dem Layer
    let detail: String          // z.B. "1294× Vollstein 39×19,5 + 50× Halbstein 19,5×19,5"
    var id: String { name }
    var einheit: String { art == .flaeche ? "m²" : "St" }
}

struct VerlegeplanResult {
    let layer: [VerlegeLayer]
    let aufbau: [String]        // erkannte Aufbau-Layer ohne eigene Fläche (Schotter/Splitt …)
    let hinweise: [String]      // menschenlesbare Hinweise (Aufbau, Fugen …)
    /// Gesamte Pflaster-/Flächenmenge (m²) — als Vorschlag für die Aufbau-Schichten.
    var flaecheGesamt: Double { layer.filter { $0.art == .flaeche }.map(\.menge).reduce(0, +) }
    var istLeer: Bool { layer.isEmpty }
}

// MARK: - Leser

enum VerlegeplanLeser {

    /// Aufbau-Layer (Tragschicht/Bettung) — als Hinweis gemeldet, nicht als eigene Fläche geraten.
    private static let aufbauBegriffe = ["schotter", "splitt", "frostschutz", "tragschicht", "bettung", "kies", "sand"]

    /// Liest einen DXF-Verlegeplan von einer Datei.
    static func lies(url: URL) throws -> VerlegeplanResult {
        let text = try String(contentsOf: url, encoding: .utf8)
        return lies(dxf: text)
    }

    /// Liest einen DXF-Verlegeplan aus dem Dateiinhalt. Zeilenbasierter DXF-Parser,
    /// robust gegen CRLF und rechtsbündige Gruppencodes ("  8", " 10").
    static func lies(dxf text: String) -> VerlegeplanResult {
        let inserts = insertsImEntitiesTeil(text)

        // Nach (Layer, Blockname) gruppieren und zählen.
        var proLayerBlock: [String: [String: Int]] = [:]   // layer -> block -> count
        for ins in inserts {
            proLayerBlock[ins.layer, default: [:]][ins.block, default: 0] += 1
        }

        var layer: [VerlegeLayer] = []
        var hinweise: [String] = []

        for (layerName, bloecke) in proLayerBlock {
            var flaeche = 0.0
            var mitMass = 0
            var objekte = 0
            var teile: [String] = []
            for (block, anzahl) in bloecke.sorted(by: { $0.value > $1.value }) {
                objekte += anzahl
                if let fp = footprintM2(ausName: block) {
                    flaeche += Double(anzahl) * fp
                    mitMass += anzahl
                    teile.append("\(anzahl)× \(kurzMass(block))")
                } else {
                    teile.append("\(anzahl)× \(kurzName(block))")
                }
            }
            let detail = teile.joined(separator: " + ")
            if mitMass > 0 {
                // Mindestens ein Stein trägt sein Maß → Fläche aus der Zählung.
                layer.append(VerlegeLayer(name: layerName, art: .flaeche, menge: flaeche,
                                          objekte: objekte, detail: detail))
            } else {
                // Kein Maß im Namen → ehrlich als Stück ausweisen (Leistensteine, Bordsteine).
                layer.append(VerlegeLayer(name: layerName, art: .stueck, menge: Double(objekte),
                                          objekte: objekte, detail: detail))
            }
        }

        // Aufbau-Layer, die zwar definiert sind, aber keine eigenen Blöcke tragen:
        // als Hinweis melden (Tragschicht/Bettung), Menge = Pflasterfläche im View.
        let pflasterFlaeche = layer.filter { $0.art == .flaeche }.map(\.menge).reduce(0, +)
        var aufbau: [String] = []
        for name in aufbauLayerNamen(text) where !proLayerBlock.keys.contains(name) {
            aufbau.append(name)
            if pflasterFlaeche > 0 {
                hinweise.append("Aufbau erkannt: \(name) — Tragschicht/Bettung, Menge ≈ Pflasterfläche (\(fmt(pflasterFlaeche)) m²), Dicke in der Position setzen.")
            } else {
                hinweise.append("Aufbau erkannt: \(name) — Tragschicht/Bettung ohne eigene Fläche im Plan.")
            }
        }

        // Größte Fläche zuerst, dann Stück-Layer.
        layer.sort {
            if $0.art != $1.art { return $0.art == .flaeche }
            return $0.menge > $1.menge
        }
        return VerlegeplanResult(layer: layer, aufbau: aufbau, hinweise: hinweise)
    }

    // MARK: - DXF-Parsing (zeilenbasiert)

    struct Insert { let layer: String; let block: String }

    /// Alle INSERT-Blockreferenzen aus dem ENTITIES-Abschnitt: Layer (Code 8) + Blockname (Code 2).
    /// DXF ist durchgehend (Code, Wert)-paarig; wir laufen paarweise und merken uns per Flag,
    /// ob wir im ENTITIES-Abschnitt sind. Robust gegen CRLF und rechtsbündige Codes ("  8").
    static func insertsImEntitiesTeil(_ text: String) -> [Insert] {
        let zeilen = normZeilen(text)
        var result: [Insert] = []
        var inEntities = false
        var aktTyp: String? = nil
        var layer = ""
        var block = ""
        func abschluss() {
            if aktTyp == "INSERT" && !block.isEmpty {
                result.append(Insert(layer: layer.isEmpty ? "0" : layer, block: block))
            }
        }
        var i = 0
        while i + 1 < zeilen.count {
            let code = zeilen[i]; let wert = zeilen[i + 1]; i += 2
            if code == "2" && wert == "ENTITIES" { inEntities = true; continue }
            guard inEntities else { continue }
            if code == "0" {
                abschluss()
                if wert == "ENDSEC" { inEntities = false; aktTyp = nil; layer = ""; block = ""; continue }
                aktTyp = wert; layer = ""; block = ""
            } else if code == "8" {
                layer = wert
            } else if code == "2" && aktTyp == "INSERT" {
                block = wert
            }
        }
        abschluss()
        return result
    }

    /// Zeilen normalisiert: Zeilenenden vereinheitlicht, rechtsbündige Gruppencodes/Werte getrimmt.
    /// WICHTIG: Swift sieht "\r\n" als EIN Grapheme — erst CRLF→LF ersetzen, dann splitten,
    /// sonst wird eine echte (CRLF-)DXF gar nicht in Zeilen zerlegt.
    static func normZeilen(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Aufbau-Layer aus der LAYER-Tabelle (Namen mit Schotter/Splitt/…), auch wenn sie keine Blöcke tragen.
    static func aufbauLayerNamen(_ text: String) -> [String] {
        let zeilen = normZeilen(text)
        var namen: Set<String> = []
        var i = 0
        var inLayerTabelle = false
        var aktTyp: String? = nil
        while i + 1 < zeilen.count {
            let code = zeilen[i]; let wert = zeilen[i + 1]
            i += 2
            if code == "2" && wert == "LAYER" { inLayerTabelle = true }
            if code == "0" {
                aktTyp = wert
                if wert == "ENDTAB" { inLayerTabelle = false }
            }
            if inLayerTabelle && aktTyp == "LAYER" && code == "2" {
                let low = wert.lowercased()
                if aufbauBegriffe.contains(where: { low.contains($0) }) { namen.insert(wert) }
            }
        }
        return namen.sorted()
    }

    // MARK: - Maß aus dem Blocknamen

    /// Grundfläche (m²) aus einem Blocknamen wie "…39x19_5x8cm". Nimmt die ersten zwei Maße
    /// (Länge × Breite). "_" und "," sind Dezimaltrenner (DXF-sicher kodiert). nil, wenn kein Maß.
    static func footprintM2(ausName name: String) -> Double? {
        guard let (a, b, einheitCm) = ersteZweiMasse(name) else { return nil }
        let faktor = einheitCm ? 0.01 : 0.001   // cm → m bzw. mm → m
        let l = a * faktor, w = b * faktor
        let flaeche = l * w
        return flaeche > 0 ? flaeche : nil
    }

    /// Findet das erste "ZxZ[xZ]"-Muster und liefert (maß1, maß2, istCm).
    static func ersteZweiMasse(_ name: String) -> (Double, Double, Bool)? {
        let scalars = Array(name)
        var i = 0
        func leseZahl(_ start: Int) -> (Double, Int)? {
            var j = start
            var s = ""
            while j < scalars.count {
                let c = scalars[j]
                if c.isNumber { s.append(c); j += 1 }
                else if (c == "_" || c == ",") && !s.isEmpty && !s.contains(".") { s.append("."); j += 1 }
                else { break }
            }
            guard let v = Double(s), !s.isEmpty else { return nil }
            return (v, j)
        }
        while i < scalars.count {
            // Ein Maßmuster beginnt mit einer Zahl, direkt gefolgt von 'x'/'X' und einer Zahl.
            if let (a, ja) = leseZahl(i), ja < scalars.count, scalars[ja] == "x" || scalars[ja] == "X",
               let (b, jb) = leseZahl(ja + 1) {
                // Einheit: taucht "mm" im Rest auf (auch nach der 3. Zahl)? sonst cm (Steinmaß-Konvention).
                let rest = String(scalars[jb...]).lowercased()
                let istCm = !rest.contains("mm")
                return (a, b, istCm)
            }
            i += 1
        }
        return nil
    }

    // MARK: - Anzeige-Helfer

    private static func kurzMass(_ block: String) -> String {
        if let (a, b, _) = ersteZweiMasse(block) {
            return "\(kern(block)) \(fmt(a))×\(fmt(b))"
        }
        return kurzName(block)
    }
    /// Griffiges Kernwort aus einem langen Blocknamen (erstes „inhaltliches" Wort).
    private static func kern(_ block: String) -> String {
        for wort in ["Vollstein", "Halbstein", "Pflaster", "Stein"] where block.localizedCaseInsensitiveContains(wort) {
            return wort
        }
        return kurzName(block)
    }
    private static func kurzName(_ block: String) -> String {
        let w = block.split(separator: " ").prefix(2).joined(separator: " ")
        return w.isEmpty ? block : w
    }
    private static func fmt(_ d: Double) -> String {
        let r = (d * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: "%g", r)
    }
}
