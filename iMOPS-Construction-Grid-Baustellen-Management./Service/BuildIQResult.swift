import Foundation

// MARK: - BuildIQResult
/// Das Analyse-Ergebnis von BuildIQ: eine DIN 276 Kostengruppe mit Begründung.
struct BuildIQResult: Codable {
    let kg_nummer: String
    let kg_bezeichnung: String
    let konfidenz: String       // "hoch", "mittel", "niedrig"
    let begruendung: String
}
