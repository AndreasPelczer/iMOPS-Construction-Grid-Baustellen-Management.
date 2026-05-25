import Foundation

// MARK: - MopsResponse
// Antwort vom Mops-Server. Enthält die Antwort, Model-Info, Timing und Quellen.
struct MopsResponse: Codable {
    let answer: String
    let model: String
    let duration_ms: Int
    let tokens: Int
    let retrieval_ms: Int?
    let sources: [MopsSource]?
}
