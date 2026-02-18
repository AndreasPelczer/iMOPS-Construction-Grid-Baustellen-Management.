import Foundation

// MARK: - Checkliste (ein einzelner Schritt)
struct AuftragChecklistItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false
}

// MARK: - Auftragspositionen (Material / Arbeitspakete)
struct AuftragLineItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String            // z.B. "Gipskartonplatten"
    var amount: String = ""      // z.B. "120"
    var unit: String = ""        // z.B. "m2" / "Stueck" / "lfm"
    var note: String = ""        // z.B. "Knauf 12,5mm, Brandschutz"
}

// MARK: - Extras Payload (MASTER fuer Auftrag.extras)
struct AuftragExtrasPayload: Codable {

    // Modus
    var trainingMode: Bool = true

    // SOP / Checkliste
    var checklist: [AuftragChecklistItem] = []

    // Knowledge-Pins
    var pinnedProductIDs: [String] = []
    var pinnedLexikonCodes: [String] = []

    // Auftragskopf
    var orderNumber: String = ""     // "B-2026-042"
    var station: String = ""         // "EG Wohnung 3" / "OG Bad"
    var deadline: Date? = nil        // Fertigstellungstermin
    var persons: Int = 0             // Anzahl Arbeiter

    // Positionen (Material / Arbeitspakete)
    var lineItems: [AuftragLineItem] = []

    // Baustellen-spezifisch
    var gewerk: String = ""          // z.B. "Elektro", "Sanitaer"
    var planReferenz: String = ""    // Verweis auf CAD-Datei / Plannummer
}

// MARK: - JSON Helfer fuer Auftrag.extras (String?)
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

// MARK: - Kompatibilitaet
typealias ChecklistItem = AuftragChecklistItem
