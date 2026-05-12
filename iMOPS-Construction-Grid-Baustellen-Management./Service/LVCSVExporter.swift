import Foundation

enum LVCSVExporter {

    static func generate(event: Event, positionen: [LVPosition]) -> Data {
        var lines: [String] = []
        lines.append(csvRow(["PosNr", "Bezeichnung", "Menge", "Einheit", "KG-Nummer", "ArtikelNr", "Lieferant"]))

        let sorted = positionen.sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        for pos in sorted {
            let menge = pos.menge == 0 ? "" : String(format: "%g", pos.menge)
            lines.append(csvRow([
                pos.posNr ?? "",
                pos.bezeichnung ?? "",
                menge,
                pos.einheit ?? "",
                pos.kostenGruppeNummer ?? "",
                pos.artikelNummer ?? "",
                pos.lieferant ?? ""
            ]))
        }

        let csv = lines.joined(separator: "\r\n")
        return csv.data(using: .utf8) ?? Data()
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            let needsQuotes = escaped.contains(",") || escaped.contains("\"") ||
                              escaped.contains("\n") || escaped.contains("\r")
            return needsQuotes ? "\"\(escaped)\"" : escaped
        }.joined(separator: ",")
    }
}
