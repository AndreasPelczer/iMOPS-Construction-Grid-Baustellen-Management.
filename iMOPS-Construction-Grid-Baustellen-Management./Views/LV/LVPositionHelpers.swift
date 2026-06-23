import Foundation

enum LVPositionHelper {
    static func isAlternative(_ pos: LVPosition) -> Bool {
        guard let nr = pos.posNr else { return false }
        return nr.range(of: #"\.A\d"#, options: .regularExpression) != nil
    }

    static func baseNr(for nr: String) -> String {
        guard let range = nr.range(of: #"\.A\d+$"#, options: .regularExpression) else { return nr }
        return String(nr[nr.startIndex..<range.lowerBound])
    }

    static func nextAlternativeNr(for baseNr: String, existing: [LVPosition]) -> String {
        let rootNr = isAlternativeNr(baseNr) ? Self.baseNr(for: baseNr) : baseNr
        let maxIdx = existing.compactMap { $0.posNr }
            .filter { $0.hasPrefix(rootNr + ".A") }
            .compactMap { nr -> Int? in
                guard let r = nr.range(of: #"\.A(\d+)$"#, options: .regularExpression) else { return nil }
                return Int(nr[r].dropFirst(2))
            }.max() ?? 0
        return "\(rootNr).A\(maxIdx + 1)"
    }

    private static func isAlternativeNr(_ nr: String) -> Bool {
        nr.range(of: #"\.A\d"#, options: .regularExpression) != nil
    }
}

