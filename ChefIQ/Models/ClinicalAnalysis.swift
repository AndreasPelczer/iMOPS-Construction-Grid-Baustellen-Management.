import Foundation

// MARK: - ClinicalAnalysis
/// Dieses Modell spiegelt die klinische Auswertung der KI wider.
struct ClinicalAnalysis: Codable {
    let beValue: String
    let calories: String
    let fat: String
    let carbs: String
    let protein: String
    let vitamins: String?
    let medicalNote: String
    let glycemicIndex: String?
    
    // NEU: Die klinische Verzehrempfehlung (IMMER, OFT, SELTEN, NIE)
    let frequency: String

    // Struktur für die Wissens-Quellen (Wikipedia, DGE, etc.)
    struct SourceJSON: Codable {
        let q: String // Quelle
        let a: String // Aussage
    }
    
    // Das Array für die KI-Antworten (Optional zur Sicherheit)
    let sources: [SourceJSON]?

    // MARK: - CodingKeys
    /// Stellt sicher, dass alle Felder beim Decoding erkannt werden
    enum CodingKeys: String, CodingKey {
        case beValue, calories, fat, carbs, protein, vitamins, medicalNote, glycemicIndex, frequency, sources
    }
}
