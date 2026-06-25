import Foundation

public struct KGProposal: Equatable {
    public let suggestedKG: String
    public let confidence: Double
    public let begruendung: String
    public let source: String
}

struct LVDraftPosition {
    let bezeichnung: String
    let einheit: String
}

enum ExpertValidationService {
    static func prepareAnonymizedRequest(for position: LVPosition) -> String {
        prepareAnonymizedRequest(
            for: LVDraftPosition(
                bezeichnung: position.bezeichnung ?? "",
                einheit: position.einheit ?? ""
            )
        )
    }

    static func prepareAnonymizedRequest(for draft: LVDraftPosition) -> String {
        """
        LV-Position fachlich prüfen.
        Beschreibung: "\(draft.bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines))"
        Einheit: "\(draft.einheit.trimmingCharacters(in: .whitespacesAndNewlines))"

        Aufgabe:
        Schlage eine DIN-276-Kostengruppe vor.
        """
    }

    static func proposeKG(for position: LVPosition) -> KGProposal? {
        proposeKG(
            for: LVDraftPosition(
                bezeichnung: position.bezeichnung ?? "",
                einheit: position.einheit ?? ""
            )
        )
    }

    static func proposeKG(for draft: LVDraftPosition) -> KGProposal? {
        let text = "\(draft.bezeichnung) \(draft.einheit)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let rules: [Rule] = [
            Rule(
                kg: "391",
                confidence: 0.88,
                keywords: ["baustelleneinrichtung", "werkzeuge", "maschinen", "vorhaltung"],
                begruendung: "Baustelleneinrichtung, Vorhaltung oder Baustellenbetrieb passen zu KG 391."
            ),
            Rule(
                kg: "391",
                confidence: 0.86,
                keywords: ["toilette", "bauwasser", "baustrom", "anschluss"],
                begruendung: "Temporäre Baustellenversorgung passt typischerweise zur Baustelleneinrichtung."
            ),
            Rule(
                kg: "392",
                confidence: 0.9,
                keywords: ["gerust", "arbeitsgerust", "fanggerust"],
                begruendung: "Gerüste werden als eigene Maßnahmengruppe geführt."
            ),
            Rule(
                kg: "393",
                confidence: 0.88,
                keywords: ["bauzaun", "absperrung", "sicherung", "sicherungs"],
                begruendung: "Absperrung und Sicherungsmaßnahmen passen zu KG 393."
            ),
            Rule(
                kg: "212",
                confidence: 0.86,
                keywords: ["abbruch", "ruckbau", "demontage"],
                begruendung: "Abbruch- und Rückbauarbeiten gehören zu den vorbereitenden Maßnahmen."
            ),
            Rule(
                kg: "311",
                confidence: 0.84,
                keywords: ["mutterboden", "erdaushub", "boden abtragen", "baugrube", "aushub"],
                begruendung: "Erdarbeiten und Baugrubenherstellung passen zu KG 311."
            ),
            Rule(
                kg: "322",
                confidence: 0.9,
                keywords: ["fundament", "bodenplatte", "frostschurze", "streifenfundament", "flachgrundung"],
                begruendung: "Fundamente, Bodenplatten und Flachgründungen passen zu KG 322."
            ),
            Rule(
                kg: "326",
                confidence: 0.86,
                keywords: ["dranage", "drainage", "sickerleitung"],
                begruendung: "Dränagen im Gründungsbereich passen zu KG 326."
            ),
            Rule(
                kg: "331",
                confidence: 0.84,
                keywords: ["aussenwand", "außenwand", "porenbeton", "mauerwerk aussen"],
                begruendung: "Außenwand- und tragende Mauerwerkspositionen passen häufig zu KG 331."
            ),
            Rule(
                kg: "341",
                confidence: 0.82,
                keywords: ["innenwand", "tragende innenwand", "mauerwerk innen"],
                begruendung: "Innenwandpositionen passen in die KG 340er-Gruppe."
            ),
            Rule(
                kg: "351",
                confidence: 0.84,
                keywords: ["decke", "stahlbetondecke", "deckenkonstruktion"],
                begruendung: "Deckenkonstruktionen passen zu KG 351."
            ),
            Rule(
                kg: "361",
                confidence: 0.84,
                keywords: ["dachstuhl", "dachkonstruktion", "sparren", "pfette"],
                begruendung: "Dachtragwerk und Dachkonstruktionen passen zu KG 361."
            )
        ]

        return rules.first { rule in
            rule.keywords.contains { text.contains($0) }
        }
        .map {
            KGProposal(
                suggestedKG: $0.kg,
                confidence: $0.confidence,
                begruendung: $0.begruendung,
                source: "local"
            )
        }
    }

    private struct Rule {
        let kg: String
        let confidence: Double
        let keywords: [String]
        let begruendung: String
    }
}
