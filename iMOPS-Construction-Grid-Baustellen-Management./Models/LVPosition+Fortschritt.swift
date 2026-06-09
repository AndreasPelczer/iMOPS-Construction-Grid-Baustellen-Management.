import Foundation

// Welle 5.2.1 — abgeleiteter Fortschritt (Option C). Gemessenes Aufmaß verdrängt
// die geschätzte Polier-%-Anzeige, aber NUR beim Anzeigen: der manuelle Wert im
// LVFortschrittStore wird nie angefasst (R1, Buch Kap 4 — Nachweis bleibt).
// Eine Wahrheit pro Zeitpunkt (Kap 6); das System trägt sie selbst (Kap 12).
enum FortschrittWert: Equatable {
    case unbestimmt                   // kein Soll und kein manueller Wert → „—"
    case geschaetzt(prozent: Double)  // Polier-Selbsteinschätzung (andersfarbig)
    case gemessen(prozent: Double)    // aus Aufmaß abgeleitet (normalfarbig; R2.b: kann > 100 sein)
}

extension LVPosition {
    /// Gemessener Fertigstellungsgrad in % aus den Aufmaßen — nur wenn Aufmaße da
    /// sind UND ein Soll > 0 existiert (R2.a: keine Division durch 0). Kein Capping
    /// (R2.b: Mehrmenge zeigt ehrlich > 100 %).
    var gemessenerFortschrittProzent: Double? {
        guard hatAufmass, sollMenge > 0 else { return nil }
        return istMengeSumme / sollMenge * 100
    }

    /// Was Zeile und Sheet anzeigen — eine Wahrheit pro Zeitpunkt. Der manuelle
    /// Wert kommt von außen (LVFortschrittStore), damit das Modell store-frei und
    /// testbar bleibt. R1: gemessen verdrängt die Anzeige, der gespeicherte
    /// Schätzwert bleibt unangetastet.
    func displayedFortschritt(manuellerProzent: Int?) -> FortschrittWert {
        if let g = gemessenerFortschrittProzent { return .gemessen(prozent: g) }
        if let m = manuellerProzent { return .geschaetzt(prozent: Double(m)) }
        return .unbestimmt
    }
}
