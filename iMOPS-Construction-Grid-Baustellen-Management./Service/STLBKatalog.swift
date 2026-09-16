import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "STLBKatalog")

// MARK: - STLBBaustein
// Ein Textbaustein aus stlb_bausteine.yaml — der Mops-eigene „STLB".
// Trägt den fertigen Ausschreibungstext (kurz/lang) UND die Verweise auf Aufwandswert
// und Maschinen. So wird Text→Rezept deterministisch: der Baustein NENNT den Key.

struct STLBBaustein: Sendable, Equatable, Identifiable {
    let id: String              // "ERD-008"
    let gewerkSektion: String   // "erdarbeiten" (YAML-Sektion)
    let kurztext: String        // GAEB OutlTxt
    let langtext: String        // GAEB DetailTxt (mit {{platzhaltern}})
    let einheit: String
    let gewerk: String          // "Erdarbeiten"
    let din: String?
    let aufwandswertKey: String? // "erdarbeiten.graben_ausheben" → AufwandswerteKatalog.eintrag(key:)
    let maschinenKeys: [String]  // ["erdbau.minibagger_3t", ...] → MaschinenKatalog
    let tags: [String]           // Suchbegriffe (tragen Synonyme)
}

// MARK: - STLBKatalog
// Lokaler Textbaustein-Katalog + Matcher. Die EINGANGSTÜR fürs Text→Rezept:
// Position (Kurztext) → bester Baustein (über kurztext + tags) → aufwandswert_key + maschinen_keys.

final class STLBKatalog: @unchecked Sendable {
    static let shared = STLBKatalog()

    private let lock = NSLock()
    private var bausteine: [STLBBaustein] = []
    private var loaded = false
    private let yamlNames = ["stlb_bausteine"]

    private init() {}

    /// Bester Baustein zu einer LV-Leistung (Titel/Kurztext). Matcht über kurztext + tags —
    /// die tags tragen Synonyme (Steinzeugrohr, Mutterboden, Rigips …). nil unter der Hürde.
    func finde(leistung: String) -> STLBBaustein? {
        ladeFallsNoetig()
        let titel = BauTextMatcher.staemme(leistung)
        guard !titel.isEmpty else { return nil }

        var best: (score: Int, baustein: STLBBaustein)? = nil
        for b in bausteine {
            let text = "\(b.kurztext) \(b.tags.joined(separator: " "))"
            let score = BauTextMatcher.score(kandidat: text, gegen: titel)
            if score == 0 { continue }
            if best == nil || score > best!.score { best = (score, b) }
        }
        guard let x = best, x.score >= BauTextMatcher.huerde else { return nil }
        return x.baustein
    }

    func alle() -> [STLBBaustein] {
        ladeFallsNoetig()
        return bausteine
    }

    func bausteinCount() -> Int {
        ladeFallsNoetig()
        return bausteine.count
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        bausteine = []
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
        var alle: [STLBBaustein] = []
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
        bausteine = alle
        logger.info("STLB-Bausteine geladen: \(alle.count)")
    }

    /// Wurzel = { sektion: { BID: {kurztext, langtext, einheit, gewerk, din, aufwandswert_key, maschinen_keys, tags} } }
    private func parseWurzel(_ root: [String: Any]) -> [STLBBaustein] {
        var result: [STLBBaustein] = []
        for (sektion, wert) in root {
            if sektion == "meta" { continue }
            guard let inhalt = wert as? [String: Any] else { continue }
            for (bid, bw) in inhalt {
                guard let b = bw as? [String: Any],
                      let kurztext = b["kurztext"] as? String else { continue }
                let maschinen = (b["maschinen_keys"] as? [Any])?.compactMap { $0 as? String } ?? []
                let tags = (b["tags"] as? [Any])?.compactMap { $0 as? String } ?? []
                result.append(STLBBaustein(
                    id: bid,
                    gewerkSektion: sektion,
                    kurztext: kurztext,
                    langtext: (b["langtext"] as? String) ?? "",
                    einheit: (b["einheit"] as? String) ?? "",
                    gewerk: (b["gewerk"] as? String) ?? "",
                    din: b["din"] as? String,
                    aufwandswertKey: b["aufwandswert_key"] as? String,
                    maschinenKeys: maschinen,
                    tags: tags))
            }
        }
        return result
    }

    private func locateYAML(name: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "yaml", subdirectory: "Knowledge") {
            return url
        }
        return bundle.url(forResource: name, withExtension: "yaml")
    }
}
