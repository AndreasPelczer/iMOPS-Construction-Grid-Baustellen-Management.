import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BKIMarktpreis")

// MARK: - BKIMarktpreis
// Ein Markt-Referenzpreis aus BKI Baupreise (abgerechnete Objekte), je STLB-Baustein.
// KEINE Kalkulationsgrundlage — nur der Vergleich neben dem selbst gerechneten EP.
struct BKIMarktpreis: Sendable, Equatable {
    let bausteinID: String   // "STR-002" → passt zum STLBKatalog
    let bkiPosition: String  // Nachweis: welche BKI-Position
    let bkiLB: String?       // Leistungsbereich (Nachweis)
    let einheit: String      // BKI-Einheit ("m2")
    let mittel: Double        // der Ø-/Mittelwert (aus der BKI-Trefferliste) — PFLICHT
    let min: Double?          // volle Spanne optional (nur wenn per Klick geerntet)
    let von: Double?
    let bis: Double?
    let max: Double?
    let platzhalter: Bool     // true = noch kein echter BKI-Wert (nur Struktur)

    /// Anzeige: volle Spanne wenn vorhanden, sonst nur der Ø-Wert.
    var spanneText: String {
        if let mn = min, let mx = max {
            return "\(euro(mn)) – \(euro(mittel)) – \(euro(mx))/\(einheit)"
        }
        return "\(euro(mittel))/\(einheit) (Ø)"
    }
    private func euro(_ d: Double) -> String { String(format: "%g €", d) }
}

// MARK: - BKIMarktpreisKatalog
// Lädt bki_marktpreise_2026.yaml. Der Mops zeigt den Markt-Vergleich, wenn zu einem
// Baustein ein Eintrag existiert — sonst still (kein BKI-Wert = kein Vergleich).
final class BKIMarktpreisKatalog: @unchecked Sendable {
    static let shared = BKIMarktpreisKatalog()

    private let lock = NSLock()
    private var preise: [String: BKIMarktpreis] = [:]
    private var metaQuelle = "BKI Baupreise"
    private var metaRegion = ""
    private var metaStand = ""
    private var loaded = false
    private let yamlName = "bki_marktpreise_2026"

    private init() {}

    /// Der Markt-Referenzpreis zu einem STLB-Baustein (oder nil).
    func eintrag(bausteinID: String) -> BKIMarktpreis? {
        ladeFallsNoetig()
        return preise[bausteinID]
    }

    /// Quellen-Etikett für die Anzeige („BKI Baupreise online · MTK · 2026").
    var quelle: String {
        ladeFallsNoetig()
        let teile = [metaQuelle, metaRegion.isEmpty ? nil : metaRegion].compactMap { $0 }
        return teile.joined(separator: " · ")
    }
    var stand: String { ladeFallsNoetig(); return metaStand }

    func anzahl() -> Int { ladeFallsNoetig(); return preise.count }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        preise = [:]; loaded = false
    }

    // MARK: - Intern

    private func ladeFallsNoetig() {
        lock.lock(); defer { lock.unlock() }
        guard !loaded else { return }
        ladeAlle()
        loaded = true
    }

    private func ladeAlle() {
        guard let url = locateYAML(name: yamlName) else {
            logger.warning("YAML nicht im Bundle: \(self.yamlName).yaml")
            return
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard let root = try Yams.load(yaml: text) as? [String: Any] else {
                logger.error("\(self.yamlName).yaml: Wurzel ist kein Dictionary"); return
            }
            if let meta = root["meta"] as? [String: Any] {
                metaQuelle = (meta["quelle"] as? String) ?? metaQuelle
                metaRegion = (meta["regionalfaktor"] as? String) ?? ""
                metaStand = (meta["stand"] as? String) ?? ""
            }
            guard let mp = root["marktpreise"] as? [String: Any] else { return }
            for (bid, wert) in mp {
                // PFLICHT: Einheit + Mittel-/Ø-Wert (aus der BKI-Trefferliste). Die volle
                // Spanne (min/von/bis/max) ist optional — kommt nur, wenn per Klick geerntet.
                guard let e = wert as? [String: Any],
                      let einheit = e["einheit"] as? String,
                      let mittel = zahl(e["mittel"]) else { continue }
                preise[bid] = BKIMarktpreis(
                    bausteinID: bid,
                    bkiPosition: (e["bki_position"] as? String) ?? "",
                    bkiLB: e["bki_lb"] as? String,
                    einheit: einheit,
                    mittel: mittel,
                    min: zahl(e["min"]), von: zahl(e["von"]),
                    bis: zahl(e["bis"]), max: zahl(e["max"]),
                    platzhalter: (e["platzhalter"] as? Bool) ?? false)
            }
            logger.info("BKI-Marktpreise geladen: \(self.preise.count)")
        } catch {
            logger.error("\(self.yamlName).yaml Parse-Fehler: \(error.localizedDescription)")
        }
    }

    private func zahl(_ any: Any?) -> Double? {
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
