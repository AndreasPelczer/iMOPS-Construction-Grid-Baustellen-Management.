import Foundation
import GoogleGenerativeAI
import UIKit

/// Der medizinisch-klinische Nachrichtendienst via Google Gemini 2.0
class GeminiClinicalService {
    
    // Initialisierung des Modells mit dem neuen Flash 2.0 Modell
    private let model = GenerativeModel(
        name: "gemini-2.0-flash",
        apiKey: Constants.geminiAPIKey
    )

    /// Holt reinen Text von der KI (ideal für News oder Fakten)
    func fetchRawText(prompt: String) async throws -> String {
        let response = try await model.generateContent(prompt)
        return response.text ?? "Keine Information verfügbar."
    }

    /// Führt eine detaillierte klinische Analyse eines Produkts durch
    func fetchAnalysis(for productDescription: String) async throws -> ClinicalAnalysis {
        let systemPrompt = Constants.medicalSystemPrompt
        
        // Der vervollständigte Prompt mit strikter JSON-Vorgabe
        let prompt = """
        \(systemPrompt)
        Analysiere folgendes Produkt: \(productDescription)
        
        Antworte STRENG im JSON-Format auf DEUTSCH.
        PFLICHTFELDER im JSON:
        - beValue, calories, fat, carbs, protein, vitamins, medicalNote, glycemicIndex
        - frequency: Wähle EXAKT eines dieser Worte: "IMMER", "OFT", "SELTEN", "NIE".
        - sources: Ein Array mit 3 Objekten {"q": "Quelle", "a": "Fakt"}.
        """
        
        let response = try await model.generateContent(prompt)
        
        guard var jsonString = response.text else {
            throw NSError(domain: "GeminiError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Keine Antwort erhalten"])
        }
        
        // Bereinigt die KI-Antwort von Markdown-Code-Blöcken
        if jsonString.contains("```") {
            jsonString = jsonString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        guard let data = jsonString.data(using: String.Encoding.utf8) else {
            throw NSError(domain: "DecodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "UTF8 Fehler"])
        }
        
        // Wandelt das JSON in unser Swift-Modell um
        return try JSONDecoder().decode(ClinicalAnalysis.self, from: data)
    }
}
