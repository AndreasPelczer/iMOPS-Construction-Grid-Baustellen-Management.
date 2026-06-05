import Foundation

// MARK: - ExtractPlanResult
// Antwort von POST /extract-plan (Welle 4 — App-Brücke).
// Die Box liefert {metadata, waende, bewehrung, lv_positionen, bestellliste, etiketten}.
// Scheibe 1 dekodiert nur die Teile, die die App nutzt — unbekannte JSON-Felder
// (waende/bewehrung) ignoriert der Decoder. Mapping auf LVPosition kommt in Scheibe 2.

struct ExtractPlanResult: Codable {
    let metadata: ExtractMetadata
    let lvPositionen: [ExtractLVPosition]
    let bestellliste: [ExtractBestellzeile]
    let etiketten: ExtractEtiketten

    enum CodingKeys: String, CodingKey {
        case metadata
        case lvPositionen = "lv_positionen"
        case bestellliste
        case etiketten
    }
}

struct ExtractMetadata: Codable {
    let projekt: String?
    let baustelle: String?
    let datei: String?
}

// Eine LV-Position aus dem Plan (passt 1:1 auf die CoreData-Entität LVPosition).
struct ExtractLVPosition: Codable {
    let posNr: String
    let kg: String            // DIN-276-Kostengruppe (-> kostenGruppeNummer)
    let bezeichnung: String
    let einheit: String
    let menge: Double
    let quelle: String        // "statik_tabelle" | "b-plan" | "schaetzung" | …
}

// Eine Mauerwerks-Bestellzeile inkl. Mat-Nr aus dem abZ-Resolver.
struct ExtractBestellzeile: Codable {
    let artikel: String
    let matnr: String?        // Xella-Mat-Nr (-> artikelNummer), kann offen sein
    let produkt: String?
    let konfidenz: String     // "hoch" | "mittel" | "offen"
    let matHinweis: String?
    let freigabe: String?
    let lieferant: String?
    let paletten: Int?
    let steine: Int?
    let flaecheM2: Double?
    let bezugPosNr: String?
    let quelle: String?

    enum CodingKeys: String, CodingKey {
        case artikel, matnr, produkt, konfidenz, freigabe, lieferant, paletten, steine, quelle
        case matHinweis = "mat_hinweis"
        case flaecheM2 = "flaeche_m2"
        case bezugPosNr = "bezug_posNr"
    }
}

// Hart/Schätz-Etiketten: welche posNr sind belastbar, welche geschätzt.
struct ExtractEtiketten: Codable {
    let hart: [String]
    let geschaetzt: [String]
}
