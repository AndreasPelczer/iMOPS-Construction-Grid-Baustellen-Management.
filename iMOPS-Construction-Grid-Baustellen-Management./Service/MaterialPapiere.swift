//
//  MaterialPapiere.swift
//
//  „Eine Baustelle ist nicht fertig geplant, wenn nicht für jedes Teil ein
//   Sicherheitsdatenblatt vorhanden ist, wenn es eingesetzt werden soll."
//   (Andreas, Nacht 21./22.09.2026)
//
//  Zwei verschiedene Papiere, und sie tun Verschiedenes:
//
//    · Sicherheitsdatenblatt — Gefahren, Schutz, Erste Hilfe. Pflicht nach
//      GefStoffV/REACH, Grundlage für Betriebsanweisung und Unterweisung.
//      Muss AKTUELL sein: ein SDB von 2019 hilft niemandem.
//    · Technisches Merkblatt — Verarbeitung, Mischung, Trocknungszeit.
//      Keine Pflicht, aber dort steht die Liegezeit (`LiegezeitSucher` holt sie).
//
//  🔴 Das SDB wird nur für GEFAHRSTOFFE verlangt. Schotter braucht keins. Sonst
//  stünden achtzig Prozent auf rot, und ein Zustand, der immer rot ist, ist
//  Rauschen — Andreas' eigene Regel vom Vormittag.
//
//  Wie LiegezeitBuch und SonderfallBuch: JSON in Documents, gekeyt auf den
//  normalisierten Materialnamen. Kein Core Data, keine Migration — und die Papiere
//  gelten baustellenübergreifend, denn derselbe Zement ist überall derselbe Zement.
//

import Foundation
import Yams
import os

// MARK: - Was der Katalog über Gefahrstoffe weiss

struct Gefahrstoff: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let stamm: [String]
    /// 🔴 Wortstämme, die den Treffer wieder aufheben: „Pflasterstein Beton" enthält
    /// „beton", ist aber ausgehärtet und damit harmlos.
    let ausnahme: [String]?
    let bezeichnung: String
    let warum: String
    let quelleKurz: String

    enum CodingKeys: String, CodingKey {
        case id, stamm, ausnahme, bezeichnung, warum
        case quelleKurz = "quelle_kurz"
    }
}

enum GefahrstoffKatalog {

    private static let logger = Logger(subsystem: "io.imops", category: "Gefahrstoff")

    static let alle: [Gefahrstoff] = {
        guard let url = Bundle.main.url(forResource: "gefahrstoffe", withExtension: "yaml"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            logger.error("gefahrstoffe.yaml nicht gefunden")
            return []
        }
        return (try? YAMLDecoder().decode([Gefahrstoff].self, from: text)) ?? []
    }()

    /// Ist das ein Gefahrstoff? 🔴 Eine VERMUTUNG anhand des Namens: „Zementmörtel"
    /// wird erkannt, ein Handelsname wie „Ardurapid 45" nicht. Deshalb überschreibbar.
    static func erkannt(_ materialName: String) -> Gefahrstoff? {
        let text = materialName.lowercased()
        return alle.first { g in
            guard g.stamm.contains(where: { text.contains($0) }) else { return false }
            // Eine Ausnahme hebt den Treffer auf — Fertigteile sind ausgehärtet.
            return !(g.ausnahme ?? []).contains { text.contains($0) }
        }
    }
}

// MARK: - Die Papiere zu einem Material

struct MaterialPapier: Codable, Identifiable, Equatable, Sendable {
    enum Art: String, Codable, CaseIterable, Sendable {
        case sicherheitsdatenblatt
        case merkblatt

        var kurz: String {
            switch self {
            case .sicherheitsdatenblatt: return "Sicherheitsdatenblatt"
            case .merkblatt:             return "technisches Merkblatt"
            }
        }
    }

    var id: String = UUID().uuidString
    var art: Art
    /// Wo es liegt — Dateiname oder Ablageort. Bewusst Text: die Datei selbst
    /// liegt im iCloud-Ordner der Baustelle, nicht in der Datenbank.
    var ablage: String
    /// Stand des Dokuments. Ein SDB muss aktuell sein.
    var stand: Date?
    var hinterlegtVon: String = ""
    var am: Date = Date()

    /// 🔴 Ein SDB, das älter als drei Jahre ist, gilt als zu prüfen. Die Hersteller
    /// aktualisieren sie bei Rezepturänderungen; drei Jahre ist die übliche Hausregel.
    /// Beim Merkblatt spielt das keine Rolle.
    var istVeraltet: Bool {
        guard art == .sicherheitsdatenblatt, let stand else { return false }
        return stand < Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
    }
}

// MARK: - Die Ablage

final class MaterialPapierBuch {

    static let shared = MaterialPapierBuch()
    private let logger = Logger(subsystem: "io.imops", category: "Papiere")

    private var papiere: [String: [MaterialPapier]] = [:]
    /// Von Hand gesetzte Gefahrstoff-Einstufung — schlägt den Katalog.
    private var einstufung: [String: Bool] = [:]
    private let datei: URL

    private struct Inhalt: Codable {
        var papiere: [String: [MaterialPapier]] = [:]
        var einstufung: [String: Bool] = [:]
    }

    private init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datei = ordner.appendingPathComponent("materialpapiere.json")
        laden()
    }

    /// Schlüssel: kleingeschrieben, ohne Mehrfach-Leerzeichen. Derselbe Zement ist
    /// auf jeder Baustelle derselbe Zement.
    static func schluessel(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Lesen

    func papiere(fuer material: String) -> [MaterialPapier] {
        papiere[Self.schluessel(material)] ?? []
    }

    func hat(_ art: MaterialPapier.Art, fuer material: String) -> Bool {
        papiere(fuer: material).contains { $0.art == art && !$0.istVeraltet }
    }

    /// Braucht dieses Material ein Sicherheitsdatenblatt?
    /// Eine Einstufung von Hand schlägt immer den Katalog.
    func istGefahrstoff(_ material: String) -> Bool {
        if let gesetzt = einstufung[Self.schluessel(material)] { return gesetzt }
        return GefahrstoffKatalog.erkannt(material) != nil
    }

    /// Was fehlt an diesem Material?
    struct Luecke: Identifiable, Equatable {
        var id: String { material }
        let material: String
        let istGefahrstoff: Bool
        let sdbFehlt: Bool
        let sdbVeraltet: Bool
        let merkblattFehlt: Bool

        var satz: String {
            if sdbVeraltet { return "Sicherheitsdatenblatt älter als drei Jahre" }
            if sdbFehlt    { return "Sicherheitsdatenblatt fehlt" }
            return "technisches Merkblatt fehlt"
        }
    }

    /// 🔴 Nur echte Lücken: das SDB nur bei Gefahrstoffen, das Merkblatt nur als
    /// Hinweis. Ein Material ohne beides, das kein Gefahrstoff ist, meldet nichts.
    func luecke(fuer material: String) -> Luecke? {
        let gefahr = istGefahrstoff(material)
        let vorhanden = papiere(fuer: material)
        let sdb = vorhanden.first { $0.art == .sicherheitsdatenblatt }
        let sdbFehlt = gefahr && sdb == nil
        let sdbVeraltet = gefahr && (sdb?.istVeraltet ?? false)
        let merkblattFehlt = !vorhanden.contains { $0.art == .merkblatt }

        guard sdbFehlt || sdbVeraltet || (gefahr && merkblattFehlt) else { return nil }
        return Luecke(material: material, istGefahrstoff: gefahr,
                      sdbFehlt: sdbFehlt, sdbVeraltet: sdbVeraltet,
                      merkblattFehlt: merkblattFehlt)
    }

    // MARK: Schreiben

    func hinterlegen(_ papier: MaterialPapier, fuer material: String) {
        let k = Self.schluessel(material)
        var liste = papiere[k] ?? []
        liste.removeAll { $0.art == papier.art }   // eins je Art, das neueste gilt
        liste.append(papier)
        papiere[k] = liste
        sichern()
        logger.info("Papier hinterlegt: \(papier.art.rawValue, privacy: .public) für \(k, privacy: .public)")
    }

    func entfernen(_ art: MaterialPapier.Art, fuer material: String) {
        let k = Self.schluessel(material)
        papiere[k]?.removeAll { $0.art == art }
        if papiere[k]?.isEmpty == true { papiere.removeValue(forKey: k) }
        sichern()
    }

    /// Von Hand einstufen — „das ist bei uns kein Gefahrstoff" oder umgekehrt.
    func einstufen(_ material: String, istGefahrstoff: Bool) {
        einstufung[Self.schluessel(material)] = istGefahrstoff
        sichern()
    }

    // MARK: Datei

    private func laden() {
        guard let data = try? Data(contentsOf: datei),
              let i = try? JSONDecoder().decode(Inhalt.self, from: data) else { return }
        papiere = i.papiere
        einstufung = i.einstufung
    }

    private func sichern() {
        do {
            let data = try JSONEncoder().encode(Inhalt(papiere: papiere, einstufung: einstufung))
            try data.write(to: datei, options: .atomic)
        } catch {
            logger.error("Papiere nicht gesichert: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Für Tests.
    func leeren() {
        papiere = [:]; einstufung = [:]
        try? FileManager.default.removeItem(at: datei)
    }
}
