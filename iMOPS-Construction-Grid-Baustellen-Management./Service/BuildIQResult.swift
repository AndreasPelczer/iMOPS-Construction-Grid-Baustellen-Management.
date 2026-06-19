import Foundation

// MARK: - BuildIQResult
/// Das Analyse-Ergebnis von BuildIQ: eine DIN 276 Kostengruppe mit Begründung.
struct BuildIQResult: Codable {
    let kg_nummer: String
    let kg_bezeichnung: String
    let konfidenz: String
    let begruendung: String

    // NEU in Welle 5.3
    let menge: Double?           // Optional, falls der Prof keine Menge findet
    let einheit: String?         // z.B. "m³", "stk", "m"
    let menge_konfidenz: String? // "hoch" | "mittel" | "niedrig"
}
