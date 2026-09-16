import Foundation

// MARK: - BauTextMatcher
// Gemeinsame Stichwort-Logik für die Katalog-Matcher (STLB-Bausteine + Aufwandswerte).
// An echten Ausschreibungen geschärft:
//  - Einzel-Vokal-Normalisierung + leichtes Plural-Stemming (Straßenabläufe→strassenablauf)
//  - Synonyme (Steinzeugrohr→Kanalrohr)
//  - Flächen-Nomen (Wand/Innenwand …) zählen nicht als Kennwort
//  - gewertet wird die LÄNGERE der beiden Originalformen (kurzer Stamm trägt trotzdem)
enum BauTextMatcher {

    // Generische Verben + Flächen-Nomen: taugen NICHT zur Unterscheidung (normalisierte Form).
    static let stopwoerter: Set<String> = [
        "herstellen", "einbauen", "verlegen", "setzen", "montieren", "liefern",
        "ausfuhren", "arbeiten", "komplett", "inkl", "incl", "stuck", "stk",
        "und", "oder", "mit", "fur", "auf", "der", "die", "das", "von", "je",
        "wand", "wande", "innenwand", "innenwande", "aussenwand", "aussenwande",
        "trennwand", "trennwande", "zwischenwand", "zwischenwande",
    ]

    // Synonyme → auf den Katalog-Begriff vereinheitlicht (normalisierte Einzel-Vokal-Form).
    static let synonyme: [String: String] = [
        "steinzeugrohr": "kanalrohr", "steinzeug": "kanalrohr", "kunststoffrohr": "kanalrohr",
        "waschtisch": "waschbecken",
    ]

    /// klein, Umlaute auf EINEN Vokal (ä→a), nur Buchstaben/Ziffern/Leerzeichen.
    static func normalisiere(_ s: String) -> String {
        let lower = s.lowercased()
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
        return String(lower.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
    }

    /// Wörter ab 3 Zeichen, Synonyme vereinheitlicht.
    static func tokenize(_ s: String) -> [String] {
        normalisiere(s).split(separator: " ").map(String.init)
            .filter { $0.count >= 3 }.map { synonyme[$0] ?? $0 }
    }

    /// Leichtes Plural-/Flexions-Stemming: EIN Suffix abschneiden (Länge ≥ 4 bleibt).
    static func stamm(_ t: String) -> String {
        for suf in ["en", "er", "e", "n", "s"] where t.hasSuffix(suf) && t.count - suf.count >= 4 {
            return String(t.dropLast(suf.count))
        }
        return t
    }

    /// Titel → Stamm-Index (Stamm → längste Originalform).
    static func staemme(_ text: String) -> [String: Int] {
        var m: [String: Int] = [:]
        for t in Set(tokenize(text)) {
            let s = stamm(t)
            m[s] = max(m[s] ?? 0, t.count)
        }
        return m
    }

    /// Score eines Kandidaten-Textes gegen den Titel-Stamm-Index.
    /// Nur substantielle Domänenwörter (≥5 Zeichen, kein Stopwort); je Stamm einmal;
    /// gewertet die längere Originalform.
    static func score(kandidat text: String, gegen titel: [String: Int]) -> Int {
        var score = 0
        var gezaehlt = Set<String>()
        for ct in tokenize(text) where ct.count >= 5 && !stopwoerter.contains(ct) {
            let cs = stamm(ct)
            guard !gezaehlt.contains(cs), let hl = titel[cs] else { continue }
            gezaehlt.insert(cs)
            score += max(ct.count, hl)
        }
        return score
    }

    /// Mindest-Score, ab dem ein Treffer plausibel ist (ein echtes ~6-Zeichen-Domänenwort).
    static let huerde = 6
}
