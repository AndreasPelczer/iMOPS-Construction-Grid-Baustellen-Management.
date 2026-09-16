import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "AufwandswerteKatalog")

// MARK: - AufwandsTreffer
// Ein gefundener Richtwert aus aufwandswerte.yaml.
// Std pro Einheit (min/mittel/max), plus die RICHTIGE Kolonne (echte Rollen,
// z.B. "1 Baggerfahrer + 1 Helfer" — nicht das generische "Maurer/Helfer").

struct AufwandsTreffer: Sendable, Equatable {
    let gewerk: String          // z.B. "erdarbeiten"
    let key: String             // z.B. "graben_ausheben"
    let bezeichnung: String     // z.B. "Rohrgraben/Kabelgraben ausheben"
    let einheit: String         // "m", "m2", "m3", "St", "t"
    let min: Double             // Std/Einheit — optimale Bedingungen
    let mittel: Double          // Std/Einheit — Normalfall
    let max: Double             // Std/Einheit — erschwert
    let kolonne: String         // die echte Mannschaft
    let hinweis: String?
    let quellen: [String]

    /// Kurze Quellen-Zeile für die UI, z.B. "PRAXIS, PAK".
    var quelleKurz: String { quellen.joined(separator: ", ") }
}

// MARK: - AufwandswerteKatalog
// Lokale, deterministische Nachschlagetabelle für Arbeitszeit-Richtwerte.
// Ersetzt das nicht-deterministische KI-Raten als PRIMÄRvorschlag im Rezept-Assistenten;
// der Prof bleibt der Rückfall, wenn nichts matcht.
//
// Ehrlichkeit (siehe YAML-Header): das sind öffentliche Richtwerte, KEINE geschützten
// ARH-Tabellen. Immer als GELB/Schätzung anzeigen — firmeninterne Werte haben Vorrang.
//
// Verwendung:
//   if let t = await AufwandswerteKatalog.shared.finde(leistung: pos.bezeichnung, langtext: pos.langtext) {
//       // t.mittel h/Einheit, t.kolonne (richtige Rollen), t.quelleKurz
//   }
//
// Erweiterbar: weitere YAMLs einfach in `yamlNames` eintragen (z.B. eine Maschinen-Datei).

final class AufwandswerteKatalog: @unchecked Sendable {
    static let shared = AufwandswerteKatalog()

    private let lock = NSLock()
    private var eintraege: [AufwandsTreffer] = []
    private var loaded = false

    // iOS-Bundle erlaubt kein Verzeichnis-Listing — Dateien explizit pflegen.
    private let yamlNames = ["aufwandswerte"]

    // Sektionen, die KEINE Aufwands-Einträge sind (andere Schema-Form).
    private let ignoreSektionen: Set<String> = ["meta", "geraete"]

    // Wörter, die NICHT zur Unterscheidung taugen (normalisierte Einzel-Vokal-Form):
    // - generische Verben (herstellen/einbauen …) + Rückbau-Verben (demontieren …)
    // - Flächen-Nomen (Wand/Innenwand …), die sonst das definierende Wort überstimmen
    //   (sonst „Mauerwerk Innenwände“ → fälschlich „Innenwände streichen“ = Maler statt Maurer).
    private let stopwoerter: Set<String> = [
        "herstellen", "einbauen", "verlegen", "setzen", "montieren", "liefern",
        "ausfuhren", "arbeiten", "komplett", "inkl", "incl", "stuck", "stk",
        "und", "oder", "mit", "fur", "auf", "der", "die", "das", "von", "je",
        "wand", "wande", "innenwand", "innenwande", "aussenwand", "aussenwande",
        "trennwand", "trennwande", "zwischenwand", "zwischenwande",
    ]
    // Rückbau-Verben bleiben BEDEUTUNGSTRAGEND (nicht Stopwort): sonst würde ein Abbruch-Eintrag
    // („Mauerwerk abbrechen") einen Bau-Titel („Mauerwerk … tragend") gleich stark treffen.
    // Ein Abbruch-Treffer braucht so ein echtes Abbruch-Wort im Titel.

    // Synonyme → auf den Katalog-Begriff vereinheitlicht (normalisierte Einzel-Vokal-Form).
    private let synonyme: [String: String] = [
        "steinzeugrohr": "kanalrohr", "steinzeug": "kanalrohr", "kunststoffrohr": "kanalrohr",
        "waschtisch": "waschbecken",
    ]

    private init() {}

    /// Findet den best-passenden Richtwert zu einer LV-Leistung.
    /// `leistung` = Kurztext/Bezeichnung, `langtext` = voller GAEB-Langtext (optional, trägt Details).
    /// Case-insensitiv, Stichwort-Scoring. nil, wenn nichts plausibel matcht.
    func finde(leistung: String, langtext: String? = nil) -> AufwandsTreffer? {
        ladeFallsNoetig()

        // NUR der Titel (Kurztext) wählt den Eintrag. An echten Ausschreibungen erwiesen:
        // der Langtext ist zu verrauscht — Füllwörter wie „seitlich“, „entsorgen“, „Aushub
        // laden und abfahren“ ziehen den Treffer auf falsche Einträge (Steinzeugrohr →
        // „Oberboden“, WC demontieren → „Dach abdecken“). Lieber ehrlich kein Treffer (der
        // Prof/die ROT-Liste fängt es) als ein selbstsicher falscher.
        // `langtext` bleibt in der Signatur — er geht weiter an den Prof und in die Anzeige.
        _ = langtext
        return besterTreffer(Set(tokenize(normalisiere(leistung))))
    }

    /// Bestbewerteter Eintrag zu einer Token-Menge, oder nil unter der Hürde.
    /// Vergleich über Wortstämme (Plural-tolerant); nur substantielle Domänenwörter (≥5 Zeichen,
    /// kein Stopwort) zählen. Gewertet wird die LÄNGERE der beiden Originalformen — so trägt ein
    /// spezifisches Positionswort (z. B. „stürze“) auch über einen kurzen Katalog-Stamm („sturz“).
    private func besterTreffer(_ heuTokens: Set<String>) -> AufwandsTreffer? {
        guard !heuTokens.isEmpty else { return nil }
        // Stamm → längste Originalform im Suchtext
        var heuStamm: [String: Int] = [:]
        for t in heuTokens {
            let s = stamm(t)
            heuStamm[s] = max(heuStamm[s] ?? 0, t.count)
        }

        var best: (score: Int, treffer: AufwandsTreffer)? = nil
        for e in eintraege {
            let kandidat = tokenize(normalisiere("\(e.bezeichnung) \(e.key.replacingOccurrences(of: "_", with: " "))"))
            var score = 0
            var gezaehlt = Set<String>()
            for ct in kandidat where ct.count >= 5 && !stopwoerter.contains(ct) {
                let cs = stamm(ct)
                guard !gezaehlt.contains(cs), let hl = heuStamm[cs] else { continue }
                gezaehlt.insert(cs)
                score += max(ct.count, hl)
            }
            if score == 0 { continue }
            // Höherer Score gewinnt; bei Gleichstand Bau vor Abbruch (Abbruch ist der
            // Sonderfall und braucht ein explizites Abbruch-Wort, sonst wäre „Mauerwerk"
            // zweideutig). Deterministisch — Dictionary-Reihenfolge darf nicht entscheiden.
            if let b = best {
                let besser = score > b.score
                    || (score == b.score && b.treffer.gewerk == "abbruch" && e.gewerk != "abbruch")
                if besser { best = (score, e) }
            } else {
                best = (score, e)
            }
        }
        // Mindesthürde: mindestens ein echtes Domänenwort (~6 Zeichen), kein Zufallstreffer.
        guard let b = best, b.score >= 6 else { return nil }
        return b.treffer
    }

    /// Alle Einträge (für Diagnose/Tests).
    func alle() -> [AufwandsTreffer] {
        ladeFallsNoetig()
        return eintraege
    }

    func eintragCount() -> Int {
        ladeFallsNoetig()
        return eintraege.count
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        eintraege = []
        loaded = false
    }

    // MARK: - Intern

    private func ladeFallsNoetig() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        ladeAlle()
        loaded = true
    }

    private func ladeAlle() {
        var alle: [AufwandsTreffer] = []
        for name in yamlNames {
            guard let url = locateYAML(name: name) else {
                logger.warning("YAML nicht im Bundle: \(name).yaml")
                continue
            }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                guard let root = try Yams.load(yaml: text) as? [String: Any] else {
                    logger.error("\(name).yaml: Wurzel ist kein Dictionary")
                    continue
                }
                alle.append(contentsOf: parseWurzel(root))
            } catch {
                logger.error("\(name).yaml Parse-Fehler: \(error.localizedDescription)")
            }
        }
        eintraege = alle
        logger.info("Aufwandswerte geladen: \(alle.count) Einträge")
    }

    /// Wurzel = { gewerk: { key: {bezeichnung, einheit, aufwandswert:{min,mittel,max}, kolonne, ...} } }
    private func parseWurzel(_ root: [String: Any]) -> [AufwandsTreffer] {
        var result: [AufwandsTreffer] = []
        for (gewerk, wert) in root {
            if ignoreSektionen.contains(gewerk) { continue }
            guard let sektion = wert as? [String: Any] else { continue }
            for (key, ew) in sektion {
                guard let e = ew as? [String: Any],
                      let aw = e["aufwandswert"] as? [String: Any],
                      let bezeichnung = e["bezeichnung"] as? String else { continue }
                guard let min = zahl(aw["min"]), let mittel = zahl(aw["mittel"]), let max = zahl(aw["max"]) else { continue }
                let quellen = (e["quellen"] as? [Any])?.compactMap { $0 as? String } ?? []
                result.append(AufwandsTreffer(
                    gewerk: gewerk,
                    key: key,
                    bezeichnung: bezeichnung,
                    einheit: (e["einheit"] as? String) ?? "",
                    min: min, mittel: mittel, max: max,
                    kolonne: (e["kolonne"] as? String) ?? "",
                    hinweis: e["hinweis"] as? String,
                    quellen: quellen))
            }
        }
        return result
    }

    /// Sucht die YAML im Bundle — zuerst im Knowledge-Subdirectory,
    /// dann im Root, falls als Group statt Folder-Reference eingebunden.
    private func locateYAML(name: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "yaml", subdirectory: "Knowledge") {
            return url
        }
        return bundle.url(forResource: name, withExtension: "yaml")
    }

    private func zahl(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    /// klein, Umlaute auf EINEN Vokal (ä→a, nicht ae), nur Buchstaben/Ziffern/Leerzeichen.
    /// Einzel-Vokal, damit Umlaut-Plurale zusammenfallen (Sturz/Stürze → sturz/sturze → sturz).
    private func normalisiere(_ s: String) -> String {
        let lower = s.lowercased()
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
        return String(lower.map { ($0.isLetter || $0.isNumber) ? $0 : " " })
    }

    /// Wörter ab 3 Zeichen, Synonyme vereinheitlicht (Steinzeugrohr = Kanalrohr usw.).
    private func tokenize(_ s: String) -> [String] {
        s.split(separator: " ").map(String.init).filter { $0.count >= 3 }.map { synonyme[$0] ?? $0 }
    }

    /// Leichtes Plural-/Flexions-Stemming: EIN Suffix abschneiden (Länge ≥ 4 bleibt).
    /// So fallen Straßenabläufe→straßenablauf, Bordsteine→bordstein, Steckdosen→steckdos.
    private func stamm(_ t: String) -> String {
        for suf in ["en", "er", "e", "n", "s"] where t.hasSuffix(suf) && t.count - suf.count >= 4 {
            return String(t.dropLast(suf.count))
        }
        return t
    }
}
