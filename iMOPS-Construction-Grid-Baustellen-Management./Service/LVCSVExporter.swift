import Foundation

enum LVCSVExporter {

    /// Trennzeichen `;` (deutsches Excel) — erlaubt Dezimal-Komma in Zahlen
    /// ohne Kollision mit dem Feldtrenner.
    private static let sep = ";"

    static func generate(event: Event, positionen: [LVPosition]) -> Data {
        var lines: [String] = []
        lines.append(csvRow([
            "PosNr", "Bezeichnung", "Menge", "Einheit", "KG-Nummer",
            "ArtikelNr", "Lieferant", "EP_netto_EUR", "GP_netto_EUR"
        ]))

        let sorted = positionen.sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        var gesamtNetto = 0.0
        for pos in sorted {
            // Gleicher Resolver wie PDF/XRechnung: Angebot → kalkulierter VK → 0.
            let ep = LVKalkulator.effektiverEP(for: pos)
            let gp = ep * pos.menge
            gesamtNetto += gp
            lines.append(csvRow([
                pos.posNr ?? "",
                pos.bezeichnung ?? "",
                dezimal(pos.menge),
                pos.einheit ?? "",
                pos.kostenGruppeNummer ?? "",
                pos.artikelNummer ?? "",
                pos.lieferant ?? "",
                ep > 0 ? geld(ep) : "",      // weich wie PDF: ohne Preis bleibt leer
                gp > 0 ? geld(gp) : ""
            ]))
        }

        // Summen-Block am Dateiende (nach Leerzeile): Netto / MwSt / Brutto.
        let mwstSatz = FirmenSettings.mwstSatz
        let mwst     = gesamtNetto * mwstSatz / 100
        let brutto   = gesamtNetto + mwst
        lines.append("")
        lines.append(csvRow(["Summe netto", geld(gesamtNetto)]))
        lines.append(csvRow(["zzgl. MwSt. \(prozent(mwstSatz)) %", geld(mwst)]))
        lines.append(csvRow(["Summe brutto", geld(brutto)]))

        let csv = lines.joined(separator: "\r\n")
        var data = Data([0xEF, 0xBB, 0xBF])              // UTF-8 BOM (Excel öffnet Umlaute korrekt)
        data.append(csv.data(using: .utf8) ?? Data())
        return data
    }

    // MARK: - Formatierung (deutsch: Dezimal-Komma)

    /// Geldbetrag, 2 Nachkommastellen, Komma als Dezimaltrenner, kein
    /// Tausenderpunkt (13842.01 → "13842,01").
    private static func geld(_ v: Double) -> String {
        String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    /// Menge in Minimaldarstellung mit Komma (33 → "33", 60.62 → "60,62").
    private static func dezimal(_ v: Double) -> String {
        v == 0 ? "" : String(format: "%g", v).replacingOccurrences(of: ".", with: ",")
    }

    private static func prozent(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            let needsQuotes = escaped.contains(sep) || escaped.contains("\"") ||
                              escaped.contains("\n") || escaped.contains("\r")
            return needsQuotes ? "\"\(escaped)\"" : escaped
        }.joined(separator: sep)
    }
}
