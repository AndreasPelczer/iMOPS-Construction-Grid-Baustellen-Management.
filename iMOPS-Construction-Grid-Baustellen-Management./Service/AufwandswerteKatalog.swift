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

    private init() {}

    /// Deterministischer Lookup per Key „gewerk.key" (z. B. „erdarbeiten.graben_ausheben").
    /// Der Weg über den STLB: Baustein nennt den Key exakt — kein Raten mehr.
    func eintrag(key: String) -> AufwandsTreffer? {
        ladeFallsNoetig()
        return eintraege.first { "\($0.gewerk).\($0.key)" == key }
    }

    /// Findet den best-passenden Richtwert zu einer LV-Leistung (Stichwort-Fallback,
    /// wenn kein STLB-Baustein greift). NUR der Titel wählt — der Langtext ist zu verrauscht.
    func finde(leistung: String, langtext: String? = nil) -> AufwandsTreffer? {
        ladeFallsNoetig()
        _ = langtext   // bleibt für den Prof/die Anzeige, nicht fürs Auswählen
        let titel = BauTextMatcher.staemme(leistung)
        guard !titel.isEmpty else { return nil }

        var best: (score: Int, treffer: AufwandsTreffer)? = nil
        for e in eintraege {
            let score = BauTextMatcher.score(
                kandidat: "\(e.bezeichnung) \(e.key.replacingOccurrences(of: "_", with: " "))",
                gegen: titel)
            if score == 0 { continue }
            // Höherer Score gewinnt; bei Gleichstand Bau vor Abbruch (Abbruch ist der Sonderfall,
            // braucht ein explizites Abbruch-Wort). Deterministisch, nicht Dictionary-abhängig.
            if let b = best {
                let besser = score > b.score
                    || (score == b.score && b.treffer.gewerk == "abbruch" && e.gewerk != "abbruch")
                if besser { best = (score, e) }
            } else {
                best = (score, e)
            }
        }
        guard let b = best, b.score >= BauTextMatcher.huerde else { return nil }
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
}
