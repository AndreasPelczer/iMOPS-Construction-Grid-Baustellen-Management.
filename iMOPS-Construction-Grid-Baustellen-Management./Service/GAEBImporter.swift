import Foundation

// MARK: - Models

struct GAEBImportResult {
    var gaebVersion: String = "3.3"
    var projectName: String = ""
    var projectLabel: String = ""
    var currency: String = "EUR"
    var dp: Int = 83          // 83 = Angebotsaufforderung, 84 = Angebot
    var ownerName: String = ""
    var items: [GAEBImportItem] = []
}

struct GAEBImportItem: Identifiable {
    let id = UUID()
    var posNr: String
    var kurztext: String
    var langtext: String
    var menge: Double
    var einheit: String          // already mapped to iMOPS display form
    var unitPrice: Double?       // only present in X84
    var groupTitle: String       // parent BoQCtgy title
    var guessedKG: String        // auto-detected DIN-276 KG
    var isAlternative: Bool
    var isSelected: Bool = true
}

// MARK: - Error

enum GAEBImportError: LocalizedError {
    case fileNotReadable
    case parseError(String)
    case noItemsFound
    var errorDescription: String? {
        switch self {
        case .fileNotReadable:   return "Datei konnte nicht gelesen werden."
        case .parseError(let m): return "XML-Fehler: \(m)"
        case .noItemsFound:      return "Keine LV-Positionen in der Datei gefunden."
        }
    }
}

// MARK: - Importer

struct GAEBImporter {

    static func parse(url: URL) throws -> GAEBImportResult {
        guard var data = try? Data(contentsOf: url) else {
            throw GAEBImportError.fileNotReadable
        }
        data = normaliseEncoding(data)

        let delegate = GAEBXMLDelegate()
        let parser   = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false  // tolerate any namespace prefix

        guard parser.parse() else {
            let msg = parser.parserError?.localizedDescription ?? "Unbekannt"
            throw GAEBImportError.parseError(msg)
        }
        guard !delegate.result.items.isEmpty else {
            throw GAEBImportError.noItemsFound
        }
        return delegate.result
    }

    // MARK: - Encoding

    private static func normaliseEncoding(_ data: Data) -> Data {
        // Valid UTF-8? Done.
        if String(data: data, encoding: .utf8) != nil { return data }
        // Try Windows-1252 (common in old GAEB files)
        if let str = String(data: data, encoding: .windowsCP1252),
           let utf8 = str.data(using: .utf8) {
            // Patch the XML declaration so XMLParser won't reject it
            var s = String(decoding: utf8, as: UTF8.self)
            s = s.replacingOccurrences(of: "encoding=\"windows-1252\"",
                                       with: "encoding=\"UTF-8\"",
                                       options: .caseInsensitive)
            s = s.replacingOccurrences(of: "encoding=\"iso-8859-1\"",
                                       with: "encoding=\"UTF-8\"",
                                       options: .caseInsensitive)
            return s.data(using: .utf8) ?? utf8
        }
        return data
    }
}

// MARK: - SAX Delegate

private final class GAEBXMLDelegate: NSObject, XMLParserDelegate {

    var result = GAEBImportResult()

    // ---- parser state ----
    private var pathStack: [String] = []
    private var currentText = ""

    // Groups
    private var groupStack: [(title: String, kg: String)] = []

    // Current item being built
    private var currentItem: GAEBImportItem?
    private var itemLangLines: [String] = []

    // path helper
    private var path: String { pathStack.joined(separator: "/") }
    private func inPath(_ needle: String) -> Bool { path.contains(needle) }

    // MARK: start element
    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        pathStack.append(elementName)
        currentText = ""

        switch elementName {
        case "BoQCtgy":
            groupStack.append((title: "", kg: ""))

        case "Item":
            let itemID  = attributeDict["ID"] ?? ""
            let rnoPart = attributeDict["RNoPart"] ?? ""
            let posNr   = itemID.isEmpty ? rnoPart : itemID
            let grp     = groupStack.last
            currentItem = GAEBImportItem(
                posNr:        posNr,
                kurztext:     "",
                langtext:     "",
                menge:        0,
                einheit:      "",
                groupTitle:   grp?.title ?? "",
                guessedKG:    grp?.kg.isEmpty == false ? grp!.kg : "300",
                isAlternative: false
            )
            itemLangLines = []

        default: break
        }
    }

    // MARK: characters
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    // MARK: end element
    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName: String?) {
        defer {
            if !pathStack.isEmpty { pathStack.removeLast() }
            currentText = ""
        }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || ["Item", "BoQCtgy", "Alt"].contains(elementName) else { return }

        switch elementName {

        // --- Project header ---
        case "Version"  where inPath("GAEBInfo"): result.gaebVersion = text
        case "NamePrj":  result.projectName = text
        case "LblPrj":   result.projectLabel = text
        case "Cur":      result.currency = text
        case "DP":       result.dp = Int(text) ?? 83
        case "Name"     where inPath("OWN"):   result.ownerName = text

        // --- Group (BoQCtgy) ---
        case "TextComplete" where inPath("BoQCtgy") && !inPath("Item"):
            if !groupStack.isEmpty {
                groupStack[groupStack.count - 1].title = text
                groupStack[groupStack.count - 1].kg    = kgFromTitle(text)
            }

        case "BoQCtgy":
            if !groupStack.isEmpty { groupStack.removeLast() }

        // --- Item fields ---
        case "TextComplete" where inPath("Item"):
            if currentItem?.kurztext.isEmpty == true { currentItem?.kurztext = text }

        case "span" where inPath("Item"):
            if !text.isEmpty { itemLangLines.append(text) }

        case "Qty" where currentItem != nil:
            // GAEB uses dot as decimal separator
            currentItem?.menge = Double(text) ?? 0

        case "QU" where currentItem != nil:
            currentItem?.einheit = mapUnit(text)

        case "UP" where currentItem != nil:
            currentItem?.unitPrice = Double(text)

        case "Alt" where currentItem != nil:
            currentItem?.isAlternative = true

        case "Item":
            guard var item = currentItem else { break }
            if item.kurztext.isEmpty { item.kurztext = itemLangLines.first ?? "" }
            item.langtext = itemLangLines.joined(separator: "\n")
            if item.guessedKG.isEmpty { item.guessedKG = "300" }
            result.items.append(item)
            currentItem = nil

        default: break
        }
    }

    // MARK: - Unit mapping (GAEB → iMOPS)
    private func mapUnit(_ u: String) -> String {
        switch u.lowercased().trimmingCharacters(in: .whitespaces) {
        case "m2", "qm":          return "m²"
        case "m3", "cbm":         return "m³"
        case "lfdm", "lfm", "lm": return "lfm"
        case "m":                  return "m"
        case "stk", "stück", "st": return "Stück"
        case "kgm", "kg":          return "kg"
        case "tne", "t", "to":     return "t"
        case "psch", "ls", "pauschal", "psch.": return "Psch"
        case "hur", "h", "std":   return "h"
        case "l", "lt", "ltr":    return "l"
        default: return u
        }
    }

    // MARK: - KG heuristic from group title
    private func kgFromTitle(_ t: String) -> String {
        let l = t.lowercased()
        if l.contains("grundstück") || l.contains("grundstueck")                 { return "100" }
        if l.contains("herrichten") || l.contains("erschlie")                     { return "200" }
        if l.contains("baugrube")  || l.contains("aushub")                        { return "310" }
        if l.contains("gründung") || l.contains("gruendung") || l.contains("fundament") { return "320" }
        if l.contains("außenwand") || l.contains("mauerwerk") || l.contains("fassade")  { return "330" }
        if l.contains("innenwand")                                                 { return "340" }
        if l.contains("decken")                                                   { return "350" }
        if l.contains("dach")                                                     { return "360" }
        if l.contains("fenster") || l.contains("tür") || l.contains("türen")      { return "380" }
        if l.contains("baukonstruktion") || l.contains("rohbau")                  { return "300" }
        if l.contains("abwasser") || l.contains("sanitär")                        { return "410" }
        if l.contains("heizung") || l.contains("wärme")                           { return "420" }
        if l.contains("lüftung") || l.contains("klima")                           { return "430" }
        if l.contains("elektro") || l.contains("starkstrom")                      { return "440" }
        if l.contains("fernmelde") || l.contains("it-anlage") || l.contains("schwachstrom") { return "450" }
        if l.contains("technische anlage") || l.contains("haustechnik")           { return "400" }
        if l.contains("außenanlage") || l.contains("freianlagen") || l.contains("garten") { return "500" }
        if l.contains("ausstattung")                                               { return "600" }
        if l.contains("baunebenkosten") || l.contains("planung")                  { return "700" }
        return "300"  // fallback: Baukonstruktionen
    }
}
