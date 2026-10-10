//
//  OfflineUnterlagen.swift
//  „Offline mitnehmen“ (10.10.2026): die Unterlagen einer Baustelle aus der Freigabe aufs iPad.
//
//  Seit 10.10. ist der iMOPS-Ordner eine Freigabe auf der Box (smb://mops-box/imops) und
//  Baustelle = Ordner. Grenze: ohne Netz ist die Freigabe nicht da. Andreas: „wenn ich mal
//  offline bin oder Baustelle ohne Empfang“. Also: vor der Fahrt die Unterlagen DIESER Baustelle
//  holen, später abgleichen (neu/geändert holen, drüben Gelöschtes wegräumen).
//
//  Version 1: nur MITNEHMEN, nicht zurückschreiben. Die Freigabe bleibt die Wahrheit.
//  Liegt unter Application Support/Offline/<Baustellen-Nummer>/<Fach>/<Datei> + stand.json.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "OfflineUnterlagen")

enum OfflineUnterlagen {

    struct Datei: Codable, Equatable, Identifiable {
        var name: String
        var fach: String
        var pfad: String
        var groesse: Int
        var geaendert: String
        var id: String { pfad }
    }

    struct Liste: Codable {
        var ordner: String?
        var dateien: [Datei]
    }

    struct Stand: Codable, Equatable {
        var ordner: String
        var geholt: Date
        var dateien: [Datei]
        var bytes: Int { dateien.reduce(0) { $0 + $1.groesse } }
    }

    enum Ergebnis: Equatable {
        case ok(neu: Int, gleich: Int, entfernt: Int)
        case keinOrdner
        case nichtErreicht(String)
    }

    // MARK: - Ort auf dem Gerät

    static func ordner(fuer bid: String, basis: URL? = nil) -> URL {
        let b = basis ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return b.appendingPathComponent("Offline", isDirectory: true)
            .appendingPathComponent(bid.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
    }

    static func stand(fuer bid: String, basis: URL? = nil) -> Stand? {
        let url = ordner(fuer: bid, basis: basis).appendingPathComponent("stand.json")
        guard let d = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(Stand.self, from: d)
    }

    static func lokal(_ d: Datei, bid: String, basis: URL? = nil) -> URL {
        ordner(fuer: bid, basis: basis).appendingPathComponent(d.pfad)
    }

    /// Was zu tun ist – reine Rechnung, testbar: holen (neu oder geändert), behalten, entfernen.
    static func abgleich(alt: [Datei], neu: [Datei]) -> (holen: [Datei], gleich: [Datei], weg: [Datei]) {
        let altNach = Dictionary(uniqueKeysWithValues: alt.map { ($0.pfad, $0) })
        let neuPfade = Set(neu.map(\.pfad))
        let holen = neu.filter { n in altNach[n.pfad].map { $0.groesse != n.groesse || $0.geaendert != n.geaendert } ?? true }
        let gleich = neu.filter { n in !holen.contains(n) }
        let weg = alt.filter { !neuPfade.contains($0.pfad) }
        return (holen, gleich, weg)
    }

    // MARK: - Netz

    private static var schluessel: String { UserDefaults.standard.string(forKey: BaustellenMeldung.schluesselKey) ?? "" }

    private static func anfrage(_ pfad: String, query: [URLQueryItem] = []) -> URLRequest? {
        guard !schluessel.isEmpty, var c = URLComponents(string: MopsConfig.host + pfad) else { return nil }
        if !query.isEmpty { c.queryItems = query }
        guard let url = c.url else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 120)
        r.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
        return r
    }

    /// Mitnehmen bzw. abgleichen. Fortschritt: (fertig, gesamt).
    static func mitnehmen(bid: String, basis: URL? = nil, fortschritt: @escaping @Sendable (Int, Int) -> Void = { _, _ in }) async -> Ergebnis {
        let id = bid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bid
        guard let r = anfrage("/baustellen/\(id)/unterlagen") else { return .nichtErreicht("Kein Mops-Schlüssel in den Einstellungen.") }
        let liste: Liste
        do {
            let (d, a) = try await URLSession.shared.data(for: r)
            guard (a as? HTTPURLResponse)?.statusCode == 200 else { return .nichtErreicht("Die Box antwortet nicht wie erwartet.") }
            liste = try JSONDecoder().decode(Liste.self, from: d)
        } catch {
            return .nichtErreicht("Keine Verbindung zur Box – offline bleibt der letzte Stand.")
        }
        guard let name = liste.ordner else { return .keinOrdner }

        let alt = stand(fuer: bid, basis: basis)?.dateien ?? []
        let plan = abgleich(alt: alt, neu: liste.dateien)
        let fm = FileManager.default
        var geholt: [Datei] = plan.gleich
        for (i, d) in plan.holen.enumerated() {
            fortschritt(i, plan.holen.count)
            guard let r = anfrage("/baustellen/\(id)/datei", query: [URLQueryItem(name: "pfad", value: d.pfad)]) else { break }
            do {
                let (tmp, a) = try await URLSession.shared.download(for: r)
                guard (a as? HTTPURLResponse)?.statusCode == 200 else { continue }
                let ziel = lokal(d, bid: bid, basis: basis)
                try fm.createDirectory(at: ziel.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: ziel.path) { try fm.removeItem(at: ziel) }
                try fm.moveItem(at: tmp, to: ziel)
                geholt.append(d)
            } catch {
                logger.info("Offline: \(d.pfad, privacy: .public) nicht geholt: \(error.localizedDescription, privacy: .public)")
                if let a = alt.first(where: { $0.pfad == d.pfad }) { geholt.append(a) }   // alte Fassung bleibt, ehrlich als alt
            }
        }
        fortschritt(plan.holen.count, plan.holen.count)
        for d in plan.weg { try? fm.removeItem(at: lokal(d, bid: bid, basis: basis)) }

        let s = Stand(ordner: name, geholt: Date(), dateien: geholt.sorted { $0.pfad < $1.pfad })
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? fm.createDirectory(at: ordner(fuer: bid, basis: basis), withIntermediateDirectories: true)
        try? enc.encode(s).write(to: ordner(fuer: bid, basis: basis).appendingPathComponent("stand.json"), options: .atomic)
        return .ok(neu: geholt.count - plan.gleich.count, gleich: plan.gleich.count, entfernt: plan.weg.count)
    }

    /// Vom Gerät löschen (nur die mitgenommene Kopie – die Freigabe bleibt unberührt).
    static func vergessen(bid: String, basis: URL? = nil) {
        try? FileManager.default.removeItem(at: ordner(fuer: bid, basis: basis))
    }
}
