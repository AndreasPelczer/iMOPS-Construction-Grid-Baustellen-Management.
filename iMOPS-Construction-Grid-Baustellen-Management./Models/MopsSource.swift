import Foundation

// MARK: - MopsSource
// Eine Wissensquelle, die der Mops bei der RAG-Suche gefunden hat.
struct MopsSource: Codable, Identifiable {
    let lemma_id: String
    let titel: String
    let source_url: String?
    let score: Double
    let chunk_preview: String?

    // Identifiable ueber lemma_id + score (kann mehrere Chunks pro Lemma geben)
    var id: String { "\(lemma_id)-\(score)" }

    // Score als Prozent-String, z.B. "92%"
    var scorePercent: String {
        "\(Int(score * 100))%"
    }
}
