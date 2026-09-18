import Foundation
import CoreGraphics

/// Mess-Mathematik fürs „Plan abgreifen": aus angetippten Bild-Punkten Länge und Fläche
/// rechnen. Der Maßstab kommt aus EINER bekannten Strecke (zwei Punkte + echte Meter) —
/// dann ist jeder weitere Punkt-Abstand und jede Fläche in Metern.
///
/// So arbeitet die Firma seit je: Maßstab-Lineal auf den Plan, Haus abgreifen. Hier digital.
enum PlanMass {

    /// Abstand zweier Bildpunkte (in Bild-Einheiten, z. B. Pixel).
    static func distanz(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x), dy = Double(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Fläche eines Polygons (Gauß/Schuhband), in Bild-Einheiten². Reihenfolge egal (Betrag).
    static func flaeche(_ p: [CGPoint]) -> Double {
        guard p.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            s += Double(a.x) * Double(b.y) - Double(b.x) * Double(a.y)
        }
        return abs(s) / 2
    }

    /// Umfang eines Polygons (geschlossen), in Bild-Einheiten.
    static func umfang(_ p: [CGPoint]) -> Double {
        guard p.count >= 2 else { return 0 }
        var u = 0.0
        for i in 0..<p.count { u += distanz(p[i], p[(i + 1) % p.count]) }
        return u
    }

    /// Umschließendes Rechteck (Länge × Breite) in Bild-Einheiten.
    static func boundingLB(_ p: [CGPoint]) -> (l: Double, b: Double) {
        guard let minX = p.map({ $0.x }).min(), let maxX = p.map({ $0.x }).max(),
              let minY = p.map({ $0.y }).min(), let maxY = p.map({ $0.y }).max() else { return (0, 0) }
        let a = Double(maxX - minX), b = Double(maxY - minY)
        return (max(a, b), min(a, b))   // Länge = die größere Seite
    }

    /// Meter je Bild-Einheit aus einer Kalibrier-Strecke (zwei Punkte + echte Länge in m).
    /// nil, wenn die Punkte zusammenfallen oder die Länge ≤ 0.
    static func meterProEinheit(kalibA: CGPoint, kalibB: CGPoint, echteMeter: Double) -> Double? {
        let d = distanz(kalibA, kalibB)
        guard d > 0, echteMeter > 0 else { return nil }
        return echteMeter / d
    }

    /// Ergebnis eines abgegriffenen Polygons in Metern.
    struct Masse {
        let flaecheM2: Double
        let umfangM: Double
        let laengeM: Double
        let breiteM: Double
    }

    /// Polygon (Bildpunkte) + Maßstab → Meter-Maße.
    static func masse(polygon p: [CGPoint], meterProEinheit m: Double) -> Masse {
        let lb = boundingLB(p)
        return Masse(flaecheM2: flaeche(p) * m * m,
                     umfangM: umfang(p) * m,
                     laengeM: lb.l * m,
                     breiteM: lb.b * m)
    }
}
