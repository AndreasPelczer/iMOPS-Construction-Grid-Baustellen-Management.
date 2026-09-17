import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "MaschinenKatalog")

// MARK: - Maschine
// Eine Baumaschine aus maschinenkatalog.yaml. Verlinkt über `einsatzBei` auf die
// Aufwandswert-Tätigkeiten ("erdarbeiten.graben_ausheben") — so kennt der Mops zur
// LV-Position gleich die passenden Geräte samt Leistung und Mietkosten.
//
// Ehrlichkeit (siehe YAML-Header): Mietpreise sind öffentliche Richtwerte, regional ±20%.
// Immer GELB/Vorschlag — eigene Maschinen / Firmensätze haben Vorrang.

struct Maschine: Sendable, Equatable, Identifiable {
    let key: String                     // "minibagger_3t"
    let sektion: String                 // "erdbau"
    let bezeichnung: String             // "Minibagger 2.5-3.5 t"
    let kategorie: String?              // "Erdbau"
    let gewichtsklasse: String?         // "leicht"
    let leistung: [String: Double]      // ["m3_pro_h": 6.0, "grabtiefe_m": 3.2]
    let mieteTag: Double?               // €/Tag netto
    let mieteWoche: Double?
    let versicherungTag: Double?
    let dieselProH: Double?
    let einsatzBei: [String]            // ["erdarbeiten.graben_ausheben", ...]
    let brauchtSchein: String?
    let transport: String?
    let hinweis: String?
    let quellen: [String]

    var id: String { "\(sektion).\(key)" }
    var quelleKurz: String { quellen.joined(separator: ", ") }

    /// Die Haupt-Stundenleistung (m³/h, m²/h oder lfm/h) plus ihre Einheit — für Dauer-Schätzung.
    var hauptLeistung: (wert: Double, einheit: String)? {
        for (k, label) in [("m3_pro_h", "m³/h"), ("m2_pro_h", "m²/h"), ("m_pro_h", "m/h")] {
            if let v = leistung[k] { return (v, label) }
        }
        return nil
    }

    /// Mietsatz je Stunde (Tagessatz / 8h) — grobe Umrechnung für die Kalkulation.
    var mieteProStunde: Double? { mieteTag.map { $0 / 8.0 } }

    /// Mietkosten nach dem TAGE-Modell: Miete wird pro ANGEFANGENEM Tag abgerechnet, nicht je Stunde.
    /// Einsatzdauer aus Menge ÷ Leistung → auf ganze Tage aufgerundet × Tagessatz. Ehrlicher als €/h,
    /// weil ein halber Tag Bagger einen ganzen Miettag kostet. nil, wenn Einheit/Leistung nicht passen.
    struct Mietkosten { let tage: Int; let gesamt: Double; let proEinheit: Double; let stunden: Double }

    func mietkostenTageModell(menge: Double, einheit: String, stundenJeTag: Double = 8) -> Mietkosten? {
        guard menge > 0, let tag = mieteTag, tag > 0, let l = hauptLeistung, l.wert > 0 else { return nil }
        let passt: Bool
        switch einheit.lowercased().trimmingCharacters(in: .whitespaces) {
        case "m3", "m³": passt = l.einheit == "m³/h"
        case "m2", "m²": passt = l.einheit == "m²/h"
        case "m", "lfm", "lfdm": passt = l.einheit == "m/h"
        default: passt = false
        }
        guard passt else { return nil }
        let stunden = menge / l.wert
        let tage = max(1, Int(ceil(stunden / stundenJeTag)))
        let gesamt = Double(tage) * tag
        return Mietkosten(tage: tage, gesamt: gesamt, proEinheit: gesamt / menge, stunden: stunden)
    }

    /// Die Miete als stundenbasierte Gerätekosten-Zeile für eine LVPosition (PositionGeraet-Schema):
    /// Maschinenstunden je Einheit × effektiver €/h (Miete inkl. Tage-Aufrundung) = Miete je Einheit.
    /// So landet das Tage-Modell verlustfrei im vorhandenen stunden×satz-Kostenmodell:
    /// `stundenJeEinheit * satzProStunde * menge == mietkostenTageModell.gesamt`.
    func mietAlsGeraetzeile(menge: Double, einheit: String, stundenJeTag: Double = 8)
        -> (stundenJeEinheit: Double, satzProStunde: Double, tage: Int)? {
        guard menge > 0,
              let mk = mietkostenTageModell(menge: menge, einheit: einheit, stundenJeTag: stundenJeTag),
              mk.stunden > 0 else { return nil }
        return (mk.stunden / menge, mk.gesamt / mk.stunden, mk.tage)
    }
}

// MARK: - MaschinenKatalog
// Lokale Maschinen-Nachschlagetabelle, verzahnt mit AufwandswerteKatalog.

final class MaschinenKatalog: @unchecked Sendable {
    static let shared = MaschinenKatalog()

    private let lock = NSLock()
    private var maschinen: [Maschine] = []
    private var loaded = false

    private let yamlNames = ["maschinenkatalog"]

    private init() {}

    /// Alle Maschinen, die zu einer Aufwandswert-Tätigkeit passen.
    /// `taetigkeitKey` = "gewerk.key", z.B. "erdarbeiten.graben_ausheben".
    /// Sortiert nach Leistung (kräftigste zuerst).
    func fuerTaetigkeit(_ taetigkeitKey: String) -> [Maschine] {
        ladeFallsNoetig()
        return maschinen
            .filter { $0.einsatzBei.contains(taetigkeitKey) }
            .sorted { ($0.hauptLeistung?.wert ?? 0) > ($1.hauptLeistung?.wert ?? 0) }
    }

    /// Maschinen zu einer Liste von IDs („sektion.key", z. B. „erdbau.minibagger_3t").
    /// Der Weg über den STLB-Baustein, der die maschinen_keys direkt nennt.
    func maschinen(ids: [String]) -> [Maschine] {
        ladeFallsNoetig()
        let set = Set(ids)
        return maschinen.filter { set.contains($0.id) }
            .sorted { ($0.hauptLeistung?.wert ?? 0) > ($1.hauptLeistung?.wert ?? 0) }
    }

    func alle() -> [Maschine] {
        ladeFallsNoetig()
        return maschinen
    }

    func maschinenCount() -> Int {
        ladeFallsNoetig()
        return maschinen.count
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        maschinen = []
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
        var alle: [Maschine] = []
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
        maschinen = alle
        logger.info("Maschinen geladen: \(alle.count)")
    }

    /// Wurzel = { sektion: { key: {bezeichnung, kategorie, leistung:{...}, miete:{...}, einsatz_bei:[...], ...} } }
    private func parseWurzel(_ root: [String: Any]) -> [Maschine] {
        var result: [Maschine] = []
        for (sektion, wert) in root {
            if sektion == "meta" { continue }
            guard let inhalt = wert as? [String: Any] else { continue }
            for (key, mw) in inhalt {
                guard let m = mw as? [String: Any],
                      let bezeichnung = m["bezeichnung"] as? String else { continue }
                let leistung = (m["leistung"] as? [String: Any])?.compactMapValues(zahl) ?? [:]
                let miete = m["miete"] as? [String: Any]
                let einsatz = (m["einsatz_bei"] as? [Any])?.compactMap { $0 as? String } ?? []
                let quellen = (m["quellen"] as? [Any])?.compactMap { $0 as? String } ?? []
                result.append(Maschine(
                    key: key,
                    sektion: sektion,
                    bezeichnung: bezeichnung,
                    kategorie: m["kategorie"] as? String,
                    gewichtsklasse: m["gewichtsklasse"] as? String,
                    leistung: leistung,
                    mieteTag: zahl(miete?["tag"]),
                    mieteWoche: zahl(miete?["woche"]),
                    versicherungTag: zahl(miete?["versicherung_tag"]),
                    dieselProH: zahl(m["diesel_l_pro_h"]),
                    einsatzBei: einsatz,
                    brauchtSchein: m["braucht_schein"] as? String,
                    transport: m["transport"] as? String,
                    hinweis: m["hinweis"] as? String,
                    quellen: quellen))
            }
        }
        return result
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
