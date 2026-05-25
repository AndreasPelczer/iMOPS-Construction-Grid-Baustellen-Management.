import Foundation

// MARK: - MopsRequest
// Request-Modell fuer den Mops-Server (POST /chat).
// Wenn die Frage mit "/prof " beginnt, routet der Server automatisch zu Claude Sonnet 4.5.
struct MopsRequest: Codable {
    let question: String
    let max_tokens: Int
    let top_k: Int
}
