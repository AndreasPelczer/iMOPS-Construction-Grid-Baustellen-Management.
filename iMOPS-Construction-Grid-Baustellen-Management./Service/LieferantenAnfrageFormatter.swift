import Foundation

struct LieferantenAnfrageKontakt: Equatable {
    var name: String
    var email: String
    var betreffPrefix: String

    init(name: String, email: String = "", betreffPrefix: String = "Anfrage") {
        self.name = name
        self.email = email
        self.betreffPrefix = betreffPrefix
    }
}

struct LieferantenAnfrageKontext: Equatable {
    var baustelle: String
    var baustellenNummer: String?
    var standort: String?
    var bauherr: String?
    var datum: Date

    init(
        baustelle: String,
        baustellenNummer: String? = nil,
        standort: String? = nil,
        bauherr: String? = nil,
        datum: Date = Date()
    ) {
        self.baustelle = baustelle
        self.baustellenNummer = baustellenNummer
        self.standort = standort
        self.bauherr = bauherr
        self.datum = datum
    }
}

enum LieferantenAnfrageFormatter {
    static func betreff(kontakt: LieferantenAnfrageKontakt, kontext: LieferantenAnfrageKontext) -> String {
        "\(kontakt.betreffPrefix) - \(kontext.baustelle)"
    }

    static func text(
        kontakt: LieferantenAnfrageKontakt,
        kontext: LieferantenAnfrageKontext,
        anfrage: UniversalAnfrage
    ) -> String {
        var lines: [String] = []
        lines.append("Guten Tag,")
        lines.append("")
        lines.append("für unser Bauprojekt \"\(kontext.baustelle)\"\(ortText(kontext.standort)) benötigen wir folgende Materialien:")
        lines.append("")
        lines.append("Projekt: \(kontext.baustelle)")
        appendOptional("Baust.-Nr.", kontext.baustellenNummer, to: &lines)
        appendOptional("Standort", kontext.standort, to: &lines)
        lines.append("Datum: \(dateFormatter.string(from: kontext.datum))")
        lines.append("")
        lines.append(String(repeating: "-", count: 60))

        for (index, position) in anfrage.positionen.enumerated() {
            lines.append("\(position.posNr.isEmpty ? "\(index + 1)" : position.posNr). \(position.material)")
            lines.append("   Menge: \(format(position.menge)) \(position.einheit)")

            if let artikel = artikelnummer(from: position), !artikel.isEmpty {
                lines.append("   Art.-Nr.: \(artikel)")
            }

            lines.append("   Nachweis: \(nachweisText(position.bedarfsquelle))")
            lines.append("")
        }

        lines.append(String(repeating: "-", count: 60))
        lines.append("")
        lines.append("Bitte senden Sie uns Preis und Verfügbarkeit zu.")
        lines.append("")
        lines.append("Mit freundlichen Grüßen")
        if let bauherr = kontext.bauherr, !bauherr.isEmpty {
            lines.append(bauherr)
        }

        return lines.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static func appendOptional(_ label: String, _ value: String?, to lines: inout [String]) {
        guard let value, !value.isEmpty else { return }
        lines.append("\(label): \(value)")
    }

    private static func ortText(_ standort: String?) -> String {
        guard let standort, !standort.isEmpty else { return "" }
        return " in \(standort)"
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static func artikelnummer(from position: BedarfsPosition) -> String? {
        guard let note = position.bedarfsquelle.notiz else { return nil }
        let prefix = "Artikel: "
        guard note.hasPrefix(prefix) else { return nil }
        return String(note.dropFirst(prefix.count))
    }

    private static func nachweisText(_ quelle: BedarfsQuelle) -> String {
        var parts: [String] = [quelle.typ.rawValue.uppercased(), quelle.ref]
        if let datei = quelle.datei, !datei.isEmpty {
            parts.append(datei)
        }
        if let planblatt = quelle.planblatt, !planblatt.isEmpty {
            parts.append("Planblatt \(planblatt)")
        }
        return parts.joined(separator: " / ")
    }
}
