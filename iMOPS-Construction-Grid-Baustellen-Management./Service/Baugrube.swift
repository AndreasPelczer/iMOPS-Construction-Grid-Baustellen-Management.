import Foundation

/// Baugruben-Aushub: Grundfläche × Tiefe, optional mit Arbeitsraum (DIN 4124) und Böschung.
///
/// Anders als die Geländemodellierung (ganzes Grundstück, DXF) ist das die **Grube fürs
/// Bauwerk**: Länge × Breite × Aushubtiefe. Ehrlich eine Schätzung — die Sohle ist selten
/// exakt rechteckig, und die echte Böschung hängt am Boden (DIN 4124: verbaut, oder geböscht
/// je Bodenklasse). Aber gut fürs Kalkulieren des Bagger-/LKW-Bedarfs.
enum Baugrube {

    /// Böschung als Verhältnis horizontal:vertikal (Anzug pro Meter Tiefe).
    /// senkrecht/verbaut = 0; leicht = 0,5; 45° = 1,0.
    enum Boeschung: Double, CaseIterable, Identifiable {
        case senkrecht = 0.0     // verbaut (Spundwand/Verbau) — senkrechte Wände
        case leicht    = 0.5     // ~63° — bindiger Boden
        case mittel    = 1.0     // 45° — Regelböschung nicht bindig
        var id: Double { rawValue }
        var text: String {
            switch self {
            case .senkrecht: return "senkrecht / verbaut"
            case .leicht:    return "leicht geböscht (0,5:1)"
            case .mittel:    return "45° geböscht (1:1)"
            }
        }
    }

    struct Ergebnis {
        let grundflaeche: Double   // L × B (Bauwerk)
        let sohleFlaeche: Double   // mit Arbeitsraum (unten)
        let obenFlaeche: Double    // mit Arbeitsraum + Böschung (oben)
        let tiefe: Double
        let volumen: Double        // Aushub m³ (Prismatoid, exakt bei linearer Böschung)
    }

    /// Aushubvolumen einer rechteckigen Baugrube.
    /// - laenge/breite: Grundmaß des Bauwerks (m)
    /// - tiefe: Aushubtiefe unter GOK (m)
    /// - arbeitsraum: rundum je Seite (m, DIN 4124 meist 0,50)
    /// - boeschung: Wandanzug pro Meter Tiefe (0 = senkrecht/verbaut)
    static func aushub(laenge: Double, breite: Double, tiefe: Double,
                       arbeitsraum: Double = 0.5, boeschung: Boeschung = .senkrecht) -> Ergebnis {
        let ls = max(0, laenge) + 2 * max(0, arbeitsraum)   // Sohle (unten)
        let bs = max(0, breite) + 2 * max(0, arbeitsraum)
        let n = boeschung.rawValue
        let lo = ls + 2 * n * max(0, tiefe)                 // oben (durch Böschung breiter)
        let bo = bs + 2 * n * max(0, tiefe)

        let aSohle = ls * bs
        let aOben  = lo * bo
        let aMitte = ((ls + lo) / 2) * ((bs + bo) / 2)      // Querschnitt auf halber Höhe
        // Prismatoid-Formel — exakt für lineare Böschung (senkrecht: aSohle=aMitte=aOben → V=h·A).
        let v = max(0, tiefe) / 6 * (aSohle + 4 * aMitte + aOben)

        return Ergebnis(grundflaeche: max(0, laenge) * max(0, breite),
                        sohleFlaeche: aSohle, obenFlaeche: aOben,
                        tiefe: max(0, tiefe), volumen: v)
    }
}
