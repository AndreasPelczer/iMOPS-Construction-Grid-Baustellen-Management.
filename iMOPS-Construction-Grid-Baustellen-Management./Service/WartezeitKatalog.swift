//
//  WartezeitKatalog.swift
//
//  Die Tage, an denen niemand arbeitet — und trotzdem alles schiebt.
//
//  Andreas über die Ablaufplan-Skizze: „erst hat man den Bagger gesehen, dann ??
//  dann Zeit … es ging um Trockenzeit oder so, das habe ich sofort verstanden."
//
//  🔴 Gemessen am 21.09.2026 in der echten Datenbank: `Bauablauf` rechnet Wartezeiten
//  seit jeher mit (`AblaufKante.wartezeitTage`, CPM mit lag) — aber **alle 598
//  Voraussetzungs-Kanten standen auf 0**. Die Rechnung konnte es, nur eingetragen hat
//  sie nie jemand. Dasselbe Muster wie `istStartbar` heute früh: gebaut, getestet,
//  nie gerufen.
//
//  Der Katalog schlägt vor, mehr nicht. Die Werte sind Praxiswerte und hängen von
//  Zement, Temperatur und Bauteil ab — deshalb trägt jeder Vorschlag seinen Hinweis
//  und muss bestätigt werden. Siehe docs/WESEN-DES-MOPS.md: kennzeichnen ja, behaupten nein.
//

import Foundation
import Yams
import os

struct Wartezeit: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let aliases: [String]
    let tage: Double
    let bezeichnung: String
    let hinweis: String
    let quelleKurz: String

    enum CodingKeys: String, CodingKey {
        case id, aliases, tage, bezeichnung, hinweis
        case quelleKurz = "quelle_kurz"
    }

    /// Ist der Wert gross genug, dass man ihn nicht raten sollte?
    /// 28 Tage Estrich verschiebt einen Termin um einen Monat — das darf nie
    /// stillschweigend durchlaufen.
    var brauchtRueckfrage: Bool { tage >= 7 }
}

enum WartezeitKatalog {

    private static let logger = Logger(subsystem: "io.imops", category: "Wartezeit")

    static let alle: [Wartezeit] = {
        guard let url = Bundle.main.url(forResource: "wartezeiten", withExtension: "yaml"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            logger.error("wartezeiten.yaml nicht gefunden")
            return []
        }
        do {
            return try YAMLDecoder().decode([Wartezeit].self, from: text)
        } catch {
            logger.error("wartezeiten.yaml nicht lesbar: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }()

    /// Passt zwischen diese beiden Arbeiten eine Liegezeit?
    ///
    /// Gefragt wird nach dem VORGÄNGER — was er hinterlässt, muss trocknen oder
    /// aushärten, bevor der Nächste ran kann. („Beton härten" hängt an der Decke,
    /// nicht am Mauerwerk darüber.)
    static func vorschlag(nach vorgaenger: String) -> Wartezeit? {
        let text = vorgaenger.lowercased()
        // Der längste passende Alias gewinnt — „estrich belegreif" schlägt „estrich".
        return alle
            .compactMap { w -> (Int, Wartezeit)? in
                guard let treffer = w.aliases.first(where: { text.contains($0) }) else { return nil }
                return (treffer.count, w)
            }
            .max { $0.0 < $1.0 }?.1
    }

    /// Bequem für die Ansicht: Vorschlag für eine Kante Vorgänger → Nachfolger.
    /// Der Nachfolger zählt nur mit, wenn der Vorgänger allein nichts hergibt.
    static func vorschlag(von vorgaenger: String, zu nachfolger: String) -> Wartezeit? {
        vorschlag(nach: vorgaenger) ?? vorschlag(nach: nachfolger)
    }
}
