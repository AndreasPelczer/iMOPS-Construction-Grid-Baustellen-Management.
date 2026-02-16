import Foundation

// MARK: - QuellenInfo
/// Ein kleiner Baustein für eine einzelne Information mit Herkunftsangabe
struct QuellenInfo: Identifiable, Equatable {
    let id = UUID()
    let quelle: String  // z.B. "Wikipedia" oder "DGE"
    let aussage: String // Der eigentliche Fakt
}

// MARK: - LexikonEintrag
/// Das Haupt-Modell für den KI-Pfad (Pfad A)
struct LexikonEintrag: Identifiable, Equatable {
    let id: UUID
    let name: String
    var analysis: ClinicalAnalysis?
    
    // NEU: Hier speichern wir die verschiedenen Aussagen der Fachgesellschaften
    var quellenFakten: [QuellenInfo]

    // Initialisierer
    init(id: UUID = UUID(), name: String, analysis: ClinicalAnalysis? = nil, quellenFakten: [QuellenInfo] = []) {
        self.id = id
        self.name = name
        self.analysis = analysis
        self.quellenFakten = quellenFakten
    }

    // Vergleichs-Logik für Swift
    static func == (lhs: LexikonEintrag, rhs: LexikonEintrag) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}
