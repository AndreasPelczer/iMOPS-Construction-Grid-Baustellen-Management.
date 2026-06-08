import Foundation

// Welle 5.2 — Ampel-Status der Soll/Ist-Abweichung (Park-Zettel-Schema, Save #39).
// Bewusst UI-agnostisch (kein SwiftUI) → testbar; das Farb-Mapping liegt in der
// View-Schicht (AufmassSheet). Buch Kap 6: Zustand statt Bewertung.
enum AufmassAmpel: Equatable {
    case keinAufmass   // grau — noch nicht gemessen
    case gruen         // |Abweichung| ≤ 5 %
    case orange        // |Abweichung| ≤ 15 %
    case rot           // |Abweichung| > 15 %
}

extension LVPosition {
    /// Kein Aufmaß = grau; sonst nach |abweichungProzent| (ein Bruch: 0,05 = 5 %).
    var aufmassAmpel: AufmassAmpel {
        guard hatAufmass else { return .keinAufmass }
        let a = abs(abweichungProzent)
        if a <= 0.05 { return .gruen }
        if a <= 0.15 { return .orange }
        return .rot
    }
}
