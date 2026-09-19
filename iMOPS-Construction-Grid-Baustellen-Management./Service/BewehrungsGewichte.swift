import Foundation

// MARK: - BewehrungsGewichte
//
// Feste Bau-Daten für die Bewehrung — Raphi: „es gibt feste Werte, Matten mit kg-Zahl
// und Stabstahl bis Ø40, dazu brauchen wir Daten." Genau die hier. KEINE Schätzung:
//
// • Stabstahl: kg/m ist reine PHYSIK — Querschnitt × Stahldichte 7850 kg/m³. Gilt für
//   jeden Durchmesser (DIN 488). Darum GERECHNET, nicht als abgetippte Tabelle (die
//   könnte Tippfehler haben) — Ø12 fällt so von selbst auf 0,888 kg/m.
// • Lagermatten: kg/m² ist ein fester Wert je Typ (DIN-488-Lagermatten-Programm), als
//   Nachschlag-Tabelle. Erweiterbar; im Zweifel bestätigt die Statik den Typ.
//
// Damit rechnet der Mops die Bewehrungs-Kilo selbst (aus Ø + Länge bzw. Matten-Typ +
// Fläche), und man preist nur noch €/kg. Die MENGEN kommen aus dem Bewehrungsplan.

enum BewehrungsGewichte {

    /// Stahldichte in kg/m³ (Betonstahl B500).
    static let stahldichte = 7850.0

    /// Stabstahl (Rundstahl): kg je laufendem Meter, aus dem Durchmesser gerechnet.
    /// Ø8→0,395 · Ø10→0,617 · Ø12→0,888 · Ø16→1,578 · Ø20→2,466 · Ø40→9,865
    static func stabstahlKgProMeter(durchmesserMM d: Double) -> Double {
        let radiusM = (d / 1000) / 2
        let querschnittM2 = .pi * radiusM * radiusM
        return querschnittM2 * stahldichte
    }

    /// Gewicht Stabstahl gesamt: kg/m × Länge(m) × Anzahl Stäbe.
    static func stabstahlGewicht(durchmesserMM: Double, laengeM: Double, anzahl: Int = 1) -> Double {
        stabstahlKgProMeter(durchmesserMM: durchmesserMM) * laengeM * Double(anzahl)
    }

    /// Lagermatten: kg je m² Mattenfläche, fester Wert je Typ (Standard-Lagermatten).
    /// Schlüssel ohne „A"-Suffix; der Lookup normalisiert „Q188A" → „Q188".
    static let mattenKgProM2: [String: Double] = [
        "Q131": 2.05, "Q188": 3.02, "Q257": 4.04, "Q335": 5.26,
        "Q378": 5.93, "Q424": 6.66, "Q513": 8.05, "Q636": 9.99,
        "R131": 1.50, "R188": 2.26, "R257": 3.03, "R317": 3.74,
        "R424": 5.04, "R513": 5.79, "R636": 7.18
    ]

    /// Gewicht einer Mattenlage: kg = kg/m² × Fläche(m²). nil = Typ unbekannt.
    static func mattenGewicht(typ: String, flaecheM2: Double) -> Double? {
        guard let proM2 = mattenKgProM2[normalisiereMatte(typ)] else { return nil }
        return proM2 * flaecheM2
    }

    /// „Q188A", „q 188 a", „Q188" → „Q188".
    static func normalisiereMatte(_ typ: String) -> String {
        var s = typ.uppercased().filter { !$0.isWhitespace }
        if s.hasSuffix("A") { s = String(s.dropLast()) }
        return s
    }
}
