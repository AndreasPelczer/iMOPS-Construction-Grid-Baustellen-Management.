import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BuildIQ")

// MARK: - BuildIQService
/// Schickt erkannten Text (OCR) an Gemini und erhält eine DIN 276 KG-Zuweisung zurück.
/// Spricht die Gemini REST-API direkt über URLSession an - keine externen SDKs.
class BuildIQService {

    private let modelName = "gemini-2.0-flash"
    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String = Constants.geminiAPIKey, urlSession: URLSession = .shared) {
        self.apiKey = apiKey
        self.urlSession = urlSession
    }

    private let systemPrompt = """
    Du bist ein Baumaterial-Erkennungssystem.
    Analysiere das Foto oder den erkannten Text.
    Weise eine DIN 276 Kostengruppen-Nummer zu (z.B. 300 Bauwerk - Baukonstruktionen).
    Antworte NUR im JSON-Format:
    {"kg_nummer": "320", "kg_bezeichnung": "Gründung", "konfidenz": "hoch", "begruendung": "Beton und Bewehrung erkannt"}
    """

    /// Analysiert erkannten OCR-Text und gibt eine DIN-276-Zuweisung zurück.
    func analyzeText(_ text: String) async throws -> BuildIQResult {
        let prompt = """
        \(systemPrompt)

        Erkannter Text vom Scan: \(text)

        Antworte STRENG im JSON-Format. Keine zusätzlichen Erklärungen.
        """

        let responseText = try await generateContent(prompt: prompt)

        var jsonString = responseText
        if jsonString.contains("```") {
            jsonString = jsonString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "BuildIQError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "UTF-8 Dekodierung fehlgeschlagen"])
        }

        do {
            return try JSONDecoder().decode(BuildIQResult.self, from: data)
        } catch {
            logger.error("JSON Decode Fehler: \(error.localizedDescription) | Raw: \(jsonString)")
            throw error
        }
    }

    // MARK: - Gemini REST

    private struct GeminiRequest: Encodable {
        let contents: [Content]
        struct Content: Encodable { let parts: [Part] }
        struct Part: Encodable { let text: String }
    }

    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        struct Candidate: Decodable { let content: Content? }
        struct Content: Decodable { let parts: [Part]? }
        struct Part: Decodable { let text: String? }
    }

    private func generateContent(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "BuildIQError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "GEMINI_API_KEY fehlt in Secrets.plist."])
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)") else {
            throw NSError(domain: "BuildIQError", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Ungültige Gemini-URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiRequest(contents: [.init(parts: [.init(text: prompt)])])
        )

        let (data, response) = try await urlSession.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<keine Antwort>"
            logger.error("Gemini HTTP \(http.statusCode): \(body)")
            throw NSError(domain: "BuildIQError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Gemini HTTP \(http.statusCode): \(body)"])
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = decoded.candidates?.first?.content?.parts?.first?.text, !text.isEmpty else {
            throw NSError(domain: "BuildIQError", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Keine Antwort von Gemini erhalten"])
        }
        return text
    }
}
