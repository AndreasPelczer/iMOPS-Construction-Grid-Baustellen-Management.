import Foundation

// MARK: - Checkliste (ein einzelner Schritt)
struct AuftragChecklistItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false
}

// MARK: - Zettel: Produktionspositionen (die Zeilen vom Zettel)
struct AuftragLineItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String            // z.B. "Bulgur"
    var amount: String = ""      // z.B. "6"
    var unit: String = ""        // z.B. "Rezept" / "GN 1/1" / "Port."
    var note: String = ""        // z.B. "12 Min Dampf, danach auflockern"
}

// MARK: - Extras Payload (MASTER für Auftrag.extras)
// -> hier kommt ALLES rein: Modus, SOP, Pins, Zettelkopf, Positionen
struct AuftragExtrasPayload: Codable {

    // Modus
    var trainingMode: Bool = true

    // SOP / Checkliste
    var checklist: [AuftragChecklistItem] = []

    // Knowledge-Pins
    var pinnedProductIDs: [String] = []
    var pinnedLexikonCodes: [String] = []

    // ✅ Zettelkopf
    var orderNumber: String = ""     // "9779-04"
    var station: String = ""         // "Torhaus, E2, Teambüro"
    var deadline: Date? = nil        // Uhrzeit / Deadline
    var persons: Int = 0             // Personen/Portionen

    // ✅ Zettel-Positionen
    var lineItems: [AuftragLineItem] = []

    // ChefIQ: Allergen-Zusammenfassung (Snapshot pro Auftrag)
    var allergenSummary: [String] = []        // z.B. ["A", "G", "L"]
    var nutritionSnapshot: NutritionSnapshot? // BE, kcal etc.
}

// MARK: - Nährstoff-Snapshot (für ChefIQ PINS)
struct NutritionSnapshot: Codable, Equatable {
    var beValue: String = ""
    var calories: String = ""
    var fat: String = ""
    var carbs: String = ""
    var protein: String = ""
    var medicalNote: String = ""
}

// MARK: - JSON Helfer für Auftrag.extras (String?)
extension AuftragExtrasPayload {

    static func from(_ extrasString: String?) -> AuftragExtrasPayload {
        guard
            let s = extrasString, !s.isEmpty,
            let data = s.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(AuftragExtrasPayload.self, from: data)
        else {
            return AuftragExtrasPayload()
        }
        return decoded
    }

    func toJSONString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Kompatibilität (nur Item-Alias – KEIN Payload-Alias!)
typealias ChecklistItem = AuftragChecklistItem
