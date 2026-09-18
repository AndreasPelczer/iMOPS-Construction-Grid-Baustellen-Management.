import Foundation

/// Liest die **Höhenpunkte einer Vermessungs-DXF** (Bestandsaufnahme) und baut daraus ein
/// Höhenraster (`Gelaendemodell`) — damit der Erdmassen-Rechner den Aushub schätzen kann.
///
/// EHRLICH: das ist eine **Schätzung aus euren Messpunkten**, kein Vermesser-Ersatz. Die DXF
/// hat verstreute Punkte (Layer `1_Punkt`, `1_Festpunkte`, Höhenlinien `4_HL_*`); der Rechner
/// braucht ein Raster. Wir interpolieren (inverse Distanz) auf ein Gitter — glatt, aber am Rand
/// unschärfer. Für die Kalkulation reicht das; für die Abrechnung misst der Vermesser.
///
/// Fallen beachtet: DXF ist CP1252-kodiert und hat CRLF (`\r\n`).
enum VermessungDXFLeser {

    struct Punkt { let x: Double; let y: Double; let z: Double }

    struct Ergebnis {
        let punkte: [Punkt]
        let modell: Gelaendemodell
        let breiteM: Double
        let tiefeM: Double
    }

    /// Layer, die echte Geländehöhen tragen (nicht Kanal/Symbole/Rahmen).
    private static func istHoehenLayer(_ layer: String) -> Bool {
        let l = layer.lowercased()
        return l == "1_punkt" || l == "1_festpunkte" || l.hasPrefix("4_hl")
    }

    // MARK: - DXF → Punkte

    /// Höhenpunkte aus DXF-Daten. `data` ist die rohe DXF-Datei.
    static func punkte(ausDXF data: Data) -> [Punkt] {
        // DXF ist typischerweise Windows-1252; ISO-Latin-1 liest jedes Byte verlustfrei.
        let text = String(data: data, encoding: .isoLatin1)
            ?? String(decoding: data, as: UTF8.self)
        let zeilen = text.replacingOccurrences(of: "\r", with: "").split(separator: "\n",
                                                                          omittingEmptySubsequences: false)
        var punkte: [Punkt] = []
        var layer = ""; var x: Double?; var y: Double?; var z: Double?

        func abschluss() {
            if let x = x, let y = y, let z = z, istHoehenLayer(layer), z > 0 {
                punkte.append(Punkt(x: x, y: y, z: z))
            }
        }
        var i = 0
        while i < zeilen.count - 1 {
            let code = zeilen[i].trimmingCharacters(in: .whitespaces)
            let wert = String(zeilen[i + 1])
            switch code {
            case "0":  abschluss(); layer = ""; x = nil; y = nil; z = nil
            case "8":  layer = wert.trimmingCharacters(in: .whitespaces)
            case "10": x = Double(wert.trimmingCharacters(in: .whitespaces))
            case "20": y = Double(wert.trimmingCharacters(in: .whitespaces))
            case "30": z = Double(wert.trimmingCharacters(in: .whitespaces))
            default: break
            }
            i += 2
        }
        abschluss()
        return ausreisserRaus(punkte)
    }

    /// Ausreißer weg: Höhen weit weg vom Median (z. B. eine Kanalsohle) verfälschen das Gelände.
    private static func ausreisserRaus(_ p: [Punkt]) -> [Punkt] {
        guard p.count >= 5 else { return p }
        let zs = p.map { $0.z }.sorted()
        let median = zs[zs.count / 2]
        return p.filter { abs($0.z - median) <= 20 }   // Gelände schwankt real selten > 20 m
    }

    // MARK: - Punkte → Raster (inverse Distanz)

    /// Baut ein Höhenraster über der Punktwolke. `zellM` = Rastermaß (1 m wie DGM1).
    static func gelaendemodell(aus punkte: [Punkt], zellM: Double = 1.0) -> Gelaendemodell? {
        guard punkte.count >= 3 else { return nil }
        let xs = punkte.map { $0.x }, ys = punkte.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let breite = maxX - minX, tiefe = maxY - minY
        guard breite > 0, tiefe > 0, breite < 5000, tiefe < 5000 else { return nil }

        let spalten = max(1, Int((breite / zellM).rounded(.up)))
        let zeilenN = max(1, Int((tiefe  / zellM).rounded(.up)))
        // Gitter nicht zu fein sprengen (Speicher/Zeit auf dem Gerät).
        guard spalten * zeilenN <= 400_000 else { return nil }

        var raster: [[Double]] = []
        raster.reserveCapacity(zeilenN)
        for r in 0..<zeilenN {
            let cy = minY + (Double(r) + 0.5) * zellM
            var reihe: [Double] = []; reihe.reserveCapacity(spalten)
            for c in 0..<spalten {
                let cx = minX + (Double(c) + 0.5) * zellM
                reihe.append(idw(cx, cy, punkte))
            }
            raster.append(reihe)
        }
        return Gelaendemodell(hoehen: raster, dx: zellM, dy: zellM)
    }

    /// Inverse-Distanz-Gewichtung, Potenz 2 (Gewicht = 1/d²): nahe Punkte zählen stark, ferne kaum.
    private static func idw(_ x: Double, _ y: Double, _ punkte: [Punkt]) -> Double {
        var summe = 0.0, gewicht = 0.0
        for p in punkte {
            let dx = p.x - x, dy = p.y - y
            let d2 = dx * dx + dy * dy      // Distanz²
            if d2 < 0.01 { return p.z }     // Punkt praktisch auf der Zelle
            let w = 1.0 / d2                // Potenz 2
            summe += w * p.z; gewicht += w
        }
        return gewicht > 0 ? summe / gewicht : 0
    }

    // MARK: - Komplett: DXF → Ergebnis

    static func lies(ausDXF data: Data, zellM: Double = 1.0) -> Ergebnis? {
        let p = punkte(ausDXF: data)
        guard let modell = gelaendemodell(aus: p, zellM: zellM) else { return nil }
        let xs = p.map { $0.x }, ys = p.map { $0.y }
        return Ergebnis(punkte: p, modell: modell,
                        breiteM: (xs.max() ?? 0) - (xs.min() ?? 0),
                        tiefeM: (ys.max() ?? 0) - (ys.min() ?? 0))
    }
}
