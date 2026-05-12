import Foundation
import PDFKit

// MARK: - Parsed Position Model

struct ParsedLVPosition: Identifiable {
    let id = UUID()
    var posNr: String
    var bezeichnung: String
    var menge: Double
    var einheit: String
    var isSelected: Bool = true
    /// 0–1: how confident the parser is this is a real LV position
    var confidence: Float
}

// MARK: - Importer

struct LVPDFImporter {

    // Canonical units recognised in both German and abbreviated form
    private static let knownUnits: Set<String> = [
        "m²", "m2", "m³", "m3",
        "lfm", "lm", "m",
        "stk", "stk.", "st", "stück",
        "kg", "t", "to",
        "psch", "psch.", "pauschal",
        "h", "std",
        "l", "ltr"
    ]

    // Regex: optional leading whitespace, then position number (digits / dots / dashes)
    // e.g. "1", "1.1", "01.02.003", "1-1-001"
    private static let posNrPattern = /^(\d{1,4}(?:[.\-]\d{1,4}){0,3})\s+(.+)$/

    // MARK: - Public API

    /// Extracts text from every page of `url` and returns heuristically parsed LV positions.
    static func extract(from url: URL) -> [ParsedLVPosition] {
        guard let doc = PDFDocument(url: url) else { return [] }

        var allLines: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let text = page.string else { continue }
            let pageLines = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            allLines += pageLines
        }

        return parseLines(allLines)
    }

    // MARK: - Internal Parser

    private static func parseLines(_ lines: [String]) -> [ParsedLVPosition] {
        var result: [ParsedLVPosition] = []

        for line in lines {
            // Skip very short / very long lines (headers, page numbers, paragraphs)
            guard (6...400).contains(line.count) else { continue }

            guard let match = try? posNrPattern.firstMatch(in: line) else { continue }
            let posNr = String(match.1)
            let rest  = String(match.2).trimmingCharacters(in: .whitespacesAndNewlines)

            let tokens = rest
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard tokens.count >= 2 else { continue }

            // Last token must be a known unit
            let rawUnit  = tokens.last!
            let unitKey  = rawUnit.lowercased().replacingOccurrences(of: ".", with: "")
            guard knownUnits.contains(unitKey) else { continue }

            // Second-to-last token must parse as a positive number
            let mengeToken = tokens[tokens.count - 2]
                .replacingOccurrences(of: ".", with: "")  // German thousands separator
                .replacingOccurrences(of: ",", with: ".")
            guard let menge = Double(mengeToken), menge > 0 else { continue }

            let bezeichnung = tokens.dropLast(2).joined(separator: " ")
            guard !bezeichnung.isEmpty else { continue }

            // Higher confidence when there are enough tokens and the pos number has dots
            let hasDots = posNr.contains(".")
            let confidence: Float = (tokens.count >= 3 && hasDots) ? 0.9
                                  : tokens.count >= 3              ? 0.75
                                  :                                  0.5

            result.append(ParsedLVPosition(
                posNr:       posNr,
                bezeichnung: bezeichnung,
                menge:       menge,
                einheit:     rawUnit,
                confidence:  confidence
            ))
        }

        return result
    }
}
