//
//  GAEB90Importer.swift
//  Liest das ältere GAEB-90-Format (DA83/DA84, Dateiendung .d83/.d84) — ein
//  zeilenbasiertes Festspalten-Format, KEIN XML. Füttert dasselbe
//  `GAEBImportResult`/`GAEBImportItem`-Modell wie der DA-XML-Leser, damit die
//  Prüf- und Import-Oberfläche unverändert bleibt.
//
//  Satzarten (erste 2 Zeichen je Zeile), belegt an einer echten Dangl-GAEB-Probe:
//    00  Beginn DA        DP (83/84) in Spalte 10–11
//    01  Maßnahme-Kennung 02  Maßnahme-Bezeichnung   03  Auftraggeber
//    11  Gruppen-OZ (Titel/Los beginnt)   12  Gruppen-Bezeichnung
//    21  Position         OZ 2–10 · Menge 23–33 (11-stellig, 3 Nachkommast.) · Einheit ab 34
//    25  Kurztext (folgt auf 21)          26  Langtext-Zeilen
//    31  Gruppen-Ende     99  Datei-Ende
//    T0/T9 + 70           Transport-Umschlag (übersprungen)
//
//  Erst messen, dann behaupten: die Spalten sind an der echten Datei gemessen,
//  nicht geraten. Encoding: GAEB 90 kommt als DOS (CP850) oder ANSI (Windows-1252).
//

import Foundation

enum GAEB90Importer {

    /// Erkennt GAEB 90 grob: die erste sinnvolle Zeile beginnt mit einer bekannten
    /// Satzart (nicht mit „<" wie XML).
    static func sieht90Aus(_ data: Data) -> Bool {
        let kopf = decode(data.prefix(512))
        for zeile in kopf.split(whereSeparator: \.isNewline) {
            let t = zeile.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { continue }
            if t.hasPrefix("<") { return false }                 // XML
            let satz = String(t.prefix(2))
            return ["T0", "T9", "00", "01", "70"].contains(satz)  // GAEB 90
        }
        return false
    }

    static func parse(data: Data) throws -> GAEBImportResult {
        let text = decode(data)
        var result = GAEBImportResult(gaebVersion: "90")

        // Gruppen-Stapel: (Titel, KG). Position hängt am obersten Titel.
        var gruppen: [(title: String, kg: String)] = []
        var aktuelle: GAEBImportItem?
        var langZeilen: [String] = []

        func schliesseItem() {
            guard var item = aktuelle else { return }
            item.langtext = langZeilen.joined(separator: "\n")
            if item.kurztext.isEmpty { item.kurztext = langZeilen.first ?? "" }
            result.items.append(item)
            aktuelle = nil
            langZeilen = []
        }

        for rohZeile in text.split(whereSeparator: \.isNewline) {
            let zeile = String(rohZeile)
            guard zeile.count >= 2 else { continue }
            let satz = feld(zeile, 0, 2)

            switch satz {
            case "00":
                result.dp = Int(feld(zeile, 10, 12).trimmingCharacters(in: .whitespaces)) ?? 83

            case "01":                                  // Maßnahme-Kennung (oft mit Datum)
                let t = restText(zeile)
                if result.projectLabel.isEmpty { result.projectLabel = t }

            case "02":                                  // Maßnahme-Bezeichnung = Projektname
                let t = restText(zeile)
                if !t.isEmpty { result.projectName = t }

            case "03":                                  // Auftraggeber
                let t = restText(zeile)
                if result.ownerName.isEmpty { result.ownerName = t }

            case "11":                                  // Gruppe beginnt
                schliesseItem()
                gruppen.append((title: "", kg: ""))

            case "12":                                  // Gruppen-Bezeichnung
                if !gruppen.isEmpty {
                    let t = restText(zeile)
                    gruppen[gruppen.count - 1].title = t
                    gruppen[gruppen.count - 1].kg = GAEBImporter.kgAusGruppe(t)
                }

            case "21":                                  // Position
                schliesseItem()
                let oz = feld(zeile, 2, 11).trimmingCharacters(in: .whitespaces)
                let mengeRoh = feld(zeile, 23, 34)
                let einheitRoh = feld(zeile, 34, 38).trimmingCharacters(in: .whitespaces)
                let grp = gruppen.last
                aktuelle = GAEBImportItem(
                    posNr:        oz,
                    kurztext:     "",
                    langtext:     "",
                    menge:        menge(ausFeld: mengeRoh),
                    einheit:      GAEBImporter.mapEinheit(einheitRoh),
                    unitPrice:    nil,
                    groupTitle:   grp?.title ?? "",
                    guessedKG:    (grp?.kg.isEmpty == false) ? grp!.kg : "300",
                    isAlternative: feld(zeile, 11, 23).contains("X"),   // X = Bedarfsposition
                    isSelected:   true
                )
                langZeilen = []

            case "25":                                  // Kurztext
                if aktuelle != nil { aktuelle?.kurztext = restText(zeile) }

            case "26":                                  // Langtext-Zeile
                if aktuelle != nil {
                    let t = restText(zeile)
                    if !t.isEmpty { langZeilen.append(t) }
                }

            case "31", "99":                            // Gruppen-/Datei-Ende
                schliesseItem()
                if satz == "31", !gruppen.isEmpty { gruppen.removeLast() }

            default:
                break                                   // T0/T9/70/06/08/20 … ignorieren
            }
        }
        schliesseItem()

        guard !result.items.isEmpty else { throw GAEBImportError.noItemsFound }
        return result
    }

    // MARK: - Feld-Helfer

    /// Zeichen [von, bis) einer Zeile (fehlertolerant bei kurzen Zeilen).
    private static func feld(_ s: String, _ von: Int, _ bis: Int) -> String {
        let chars = Array(s)
        guard von < chars.count else { return "" }
        let ende = min(bis, chars.count)
        return String(chars[von..<ende])
    }

    /// Text ab Spalte 2, ohne die abschließende 6-stellige Satznummer (falls vorhanden).
    private static func restText(_ s: String) -> String {
        var chars = Array(s)
        // GAEB-90-Sätze enden oft auf eine 6-stellige Satznummer → abschneiden.
        if chars.count >= 6, chars.suffix(6).allSatisfy(\.isNumber) {
            chars.removeLast(6)
        }
        guard chars.count > 2 else { return "" }
        return String(chars[2...]).trimmingCharacters(in: .whitespaces)
    }

    /// 11-stelliges Mengenfeld mit 3 Nachkommastellen (00000600000 → 600,0).
    private static func menge(ausFeld feld: String) -> Double {
        let t = feld.trimmingCharacters(in: .whitespaces)
        guard let ganz = Int(t) else { return 0 }        // leer = Bedarfsposition → 0
        return Double(ganz) / 1000.0
    }

    // MARK: - Encoding

    /// GAEB 90 kommt als DOS (CP850) oder ANSI (Windows-1252). Wir probieren in
    /// dieser Reihenfolge und nehmen die erste Dekodierung ohne Ersatzzeichen.
    private static func decode<D: DataProtocol>(_ data: D) -> String {
        let bytes = Data(data)
        if let s = String(data: bytes, encoding: .utf8), !s.contains("\u{FFFD}") { return s }
        // CP850 (DOS-Latin-1) — bei GAEB 90 am häufigsten für m²/m³/Umlaute
        let cp850 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosLatin1.rawValue)))
        if let s = String(data: bytes, encoding: cp850), !s.contains("\u{FFFD}") { return s }
        if let s = String(data: bytes, encoding: .windowsCP1252), !s.contains("\u{FFFD}") { return s }
        return String(decoding: bytes, as: UTF8.self)    // letzter Ausweg
    }
}
