import Foundation

// MARK: - Checkliste (ein einzelner Schritt)
struct AuftragChecklistItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false

    // Übergabe-Nachweis: wer (Rolle des eingeloggten Nutzers) hat diesen Schritt
    // bewusst übernommen/abgeschlossen, und wann. Optional → alte Daten bleiben lesbar.
    // Der Beleg ist so gut wie die Anmeldung (geteilter Login verwischt ihn).
    var uebernommenVon: String? = nil
    var uebernommenAm: Date? = nil
}

// MARK: - Auftragspositionen (Material / Arbeitspakete)
struct AuftragLineItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String            // z.B. "Gipskartonplatten"
    var amount: String = ""      // z.B. "120"
    var unit: String = ""        // z.B. "m2" / "Stueck" / "lfm"
    var note: String = ""        // z.B. "Knauf 12,5mm, Brandschutz"
    var kostenGruppeNummer: String = ""  // DIN 276 KG, z.B. "334"
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

    // Übergabe (Buch „Thermodynamik der Arbeit": zweiseitig — Abgabe ohne Annahme
    // ist keine Übergabe). Abgabe = Feierabend/„bin fertig"; Annahme = der Nächste
    // übernimmt am Morgen und meldet ein Ergebnis. Alles optional → alte Daten lesbar.
    var abgegebenVon: String? = nil     // Rolle des eingeloggten Nutzers
    var abgegebenAm: Date? = nil
    var angenommenVon: String? = nil
    var angenommenAm: Date? = nil
    var annahmeErgebnis: String? = nil  // Annahmeergebnis.rawValue: ok | problem | gehtNicht
}

// MARK: - Annahme-Ergebnis (was der Übernehmende meldet)
enum Annahmeergebnis: String, CaseIterable, Identifiable {
    case ok
    case problem
    case gehtNicht

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .ok:       return "Übernommen — alles ok"
        case .problem:  return "Übernommen — mit Problem"
        case .gehtNicht: return "Geht nicht"
        }
    }

    var symbol: String {
        switch self {
        case .ok:       return "checkmark.seal.fill"
        case .problem:  return "exclamationmark.triangle.fill"
        case .gehtNicht: return "xmark.octagon.fill"
        }
    }

    /// Hält die Kette (nur „ok" gibt sie sauber weiter; Problem/Geht-nicht sind Befunde).
    var haeltDieKette: Bool { self == .ok }
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
