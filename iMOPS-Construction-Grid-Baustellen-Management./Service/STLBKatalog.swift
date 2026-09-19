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
    let material: MaterialLink?  // das Schüttgut/Material der Position (Schotter …)
    let vorhaltung: VorhaltungLink? // wiederverwendbares Betriebsmittel (Schalung) — Gerätekosten je Fläche
    let hoeheM: Double?          // Bauteil-Richthöhe (m) — Brückenmaß Länge↔Fläche (Schalung), wenn der Text keine nennt
    let dickeM: Double?          // Bauteil-Richtdicke (m) — Brückenmaß Fläche↔Volumen, wenn der Text keine nennt
    let tags: [String]           // Suchbegriffe (tragen Synonyme)

    /// Der Material-Link eines Bausteins: welches Schüttgut die Leistung braucht, in welcher
    /// Einheit es gehandelt wird, ein Praxis-Richtpreis als Rückfall (falls in den Stammdaten
    /// noch kein Preis steht) und der Verschnitt/Verlust. So findet die Auto-Bepreisung das
    /// Material — den bei Schüttgütern GRÖSSTEN Posten — über den Katalog statt gar nicht.
    struct MaterialLink: Sendable, Equatable {
        let text: String        // "Schotter 0/32" → materialPreis + lagerBestand (per Name)
        let einheit: String     // Handelseinheit des Materials ("t") — so wird's eingekauft
        let richtpreis: Double? // €/Einheit Praxis-Richtwert, falls keine Stammdaten
        let verschnitt: Double  // Anteil (0,05 = 5 %), bei Schüttgut meist 0
        let dichte: Double?     // t/m³ des MATERIALS — überbrückt eine m³-Position auf t-Handel,
                                // wenn der Positionstext (z. B. „Bettungsmaterial") keine Dichte verrät
    }

    /// Vorhaltung eines wiederverwendbaren Betriebsmittels (Schalung): NICHT verbrauchtes
    /// Material, sondern Miete/Abschreibung je Schalfläche und Einsatz → Gerätekosten. So kommt
    /// der Hauptkostenblock der Schalung neben dem Lohn ehrlich in den Preis (statt „fehlt").
    struct VorhaltungLink: Sendable, Equatable {
        let bezeichnung: String // "Fundamentschalung (Vorhaltung)"
        let proM2: Double       // €/m² Schalfläche JE Einsatz (Praxis-Richtwert)
        let einsaetze: Double   // wie oft in dieser Position eingesetzt (meist 1)
    }
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

    /// Mehrere Vorschläge zu einem (Teil-)Text — für die Autovervollständigung beim
    /// Anlegen/Bearbeiten einer Position. Nach Trefferstärke sortiert, die besten zuerst.
    func vorschlaege(zu text: String, max: Int = 6) -> [STLBBaustein] {
        ladeFallsNoetig()
        let titel = BauTextMatcher.staemme(text)
        guard !titel.isEmpty else { return [] }
        let bewertet: [(Int, STLBBaustein)] = bausteine.compactMap { b in
            let t = "\(b.kurztext) \(b.tags.joined(separator: " "))"
            let s = BauTextMatcher.score(kandidat: t, gegen: titel)
            return s > 0 ? (s, b) : nil
        }
        return bewertet.sorted { $0.0 > $1.0 }.prefix(max).map { $0.1 }
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
                var material: STLBBaustein.MaterialLink? = nil
                if let mb = b["material"] as? [String: Any],
                   let text = mb["text"] as? String, !text.isEmpty {
                    material = STLBBaustein.MaterialLink(
                        text: text,
                        einheit: (mb["einheit"] as? String) ?? "",
                        richtpreis: zahlAus(mb["richtpreis"]),
                        verschnitt: zahlAus(mb["verschnitt"]) ?? 0,
                        dichte: zahlAus(mb["dichte"]))
                }
                var vorhaltung: STLBBaustein.VorhaltungLink? = nil
                if let vb = b["vorhaltung"] as? [String: Any],
                   let proM2 = zahlAus(vb["pro_m2"]), proM2 > 0 {
                    vorhaltung = STLBBaustein.VorhaltungLink(
                        bezeichnung: (vb["bezeichnung"] as? String) ?? "Schalung (Vorhaltung)",
                        proM2: proM2,
                        einsaetze: zahlAus(vb["einsaetze"]) ?? 1)
                }
                let geo = b["geometrie"] as? [String: Any]
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
                    material: material,
                    vorhaltung: vorhaltung,
                    hoeheM: zahlAus(geo?["hoehe_m"]),
                    dickeM: zahlAus(geo?["dicke_m"]),
                    tags: tags))
            }
        }
        return result
    }

    private func zahlAus(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    private func locateYAML(name: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "yaml", subdirectory: "Knowledge") {
            return url
        }
        return bundle.url(forResource: name, withExtension: "yaml")
    }
}
