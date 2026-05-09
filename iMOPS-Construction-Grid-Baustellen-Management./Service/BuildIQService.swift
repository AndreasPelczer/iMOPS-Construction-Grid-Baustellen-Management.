import Foundation
import GoogleGenerativeAI
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BuildIQ")

// MARK: - BuildIQService
/// Schickt erkannten Text (OCR) an Gemini und erhält eine DIN 276 KG-Zuweisung zurück.
/// Analog zu GeminiClinicalService in ChefIQ.
class BuildIQService {

    private let model = GenerativeModel(
        name: "gemini-2.0-flash",
        apiKey: Constants.geminiAPIKey
    )

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

        let response = try await model.generateContent(prompt)

        guard var jsonString = response.text else {
            throw NSError(domain: "BuildIQError", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Keine Antwort von Gemini erhalten"])
        }

        // Markdown-Codeblöcke bereinigen (analog zu GeminiClinicalService)
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
}
