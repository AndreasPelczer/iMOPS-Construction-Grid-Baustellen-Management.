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

    // MARK: - 🔴 Der Mops darf nicht schweigen, wenn er es weiss

    /// Andreas, 21.09.2026: „so erkennt dann der Mops, wenn der Chef 2 Tage
    /// Trocknungszeit einträgt, aber der Zement 3 Tage braucht … **wenn irgendwann
    /// auffallen würde, der Mops wusste das, hat aber nichts gesagt.**"
    ///
    /// Das ist der Satz, um den es geht. Ein System, das einen Wert kennt und ihn
    /// für sich behält, ist schlimmer als eines, das ihn nicht kennt: es hat den
    /// Anschein von Prüfung, ohne zu prüfen. Wer später in die Akte schaut, findet
    /// den Katalogwert — und die Frage, warum niemand etwas gesagt hat.
    ///
    /// Deshalb: **sagen, nicht sperren.** Der Mops nennt seinen Wert und fragt nach.
    ///
    /// 🔴 UND ER WIDERSPRICHT NICHT. Andreas' Gegenfrage, eine Minute nachdem der
    /// erste Entwurf stand: „woher weiss der Mops das genau, der Zement auf der
    /// Baustelle 3 und nicht 2 Tage braucht?"
    ///
    /// Er weiss es nicht. Die echte Ausschalfrist hängt an der **Zementart**
    /// (CEM I 42,5 R härtet doppelt so schnell wie CEM III), der **Temperatur**
    /// (bei 5 °C dauert es doppelt so lang, bei Frost gar nicht), dem **Bauteil**
    /// (tragend oder nicht), der **Festigkeitsklasse** und der Nachbehandlung.
    /// Davon steht im Mops nichts. Wer 2 Tage einträgt, hat womöglich recht —
    /// weil er Schnellzement bestellt hat.
    ///
    /// Der Katalogwert ist also ein **Richtwert ohne Kenntnis dieser Baustelle**.
    /// Der Mops sagt deshalb nicht „das ist zu kurz", sondern „bei mir stehen
    /// 3 Tage — woher kommt deine Zahl?" Die Antwort merkt er sich
    /// (`SonderfallBuch`), und beim nächsten Mal weiss er es wirklich.
    /// Siehe die Ampel-Regel vom selben Tag: **eine Ziffer ist eine Behauptung.**
    struct ZuKurz: Equatable {
        let eingetragen: Double
        let katalog: Wartezeit
        var fehlendeTage: Double { katalog.tage - eingetragen }

        /// Der Satz für die Anzeige. Er nennt beide Zahlen und stellt eine FRAGE —
        /// der Mops behauptet nicht, es besser zu wissen.
        var satz: String {
            let e = eingetragen == 0 ? "Noch keine Liegezeit eingetragen"
                                     : "Eingetragen: \(kurz(eingetragen)) Tage"
            return "\(e). Im Katalog stehen \(kurz(katalog.tage)) Tage für "
                 + "„\(katalog.bezeichnung)\u{201C}."
        }

        /// Was der Mops NICHT weiss — und was die Zahl in Wirklichkeit bestimmt.
        /// Steht dabei, damit niemand den Richtwert für eine Messung hält.
        var wasFehlt: String {
            "Der Mops kennt weder Zementart noch Temperatur, Bauteil oder "
            + "Festigkeitsklasse — davon hängt die Zahl aber ab. Wenn du es besser "
            + "weisst, hast du recht."
        }

        /// Die Wege, die offenstehen. Der letzte kostet eine Unterschrift.
        var wege: [String] {
            ["\(kurz(katalog.tage)) Tage nehmen — den Richtwert",
             "Bei deiner Zahl bleiben und sagen, woher sie kommt",
             "Dabei bleiben ohne Begründung — dann unterschreibt, wer es entschied"]
        }

        private func kurz(_ w: Double) -> String {
            w == w.rounded() ? String(format: "%.0f", w) : String(format: "%.1f", w)
        }
    }

    /// Ist die eingetragene Liegezeit kürzer, als der Katalog es für diese Arbeit kennt?
    ///
    /// 🔴 Bewusst auch bei 0 Tagen: „gar nicht eingetragen" ist der häufigste Fall
    /// und der gefährlichste — in Andreas' Datenbank standen alle 598 Kanten auf 0.
    /// Und bewusst NUR bei einem Katalogtreffer: wo der Mops nichts weiss, sagt er
    /// nichts. Eine Warnung ins Blaue wäre schlimmer als Schweigen.
    static func pruefe(eingetragen: Double, nach vorgaenger: String) -> ZuKurz? {
        guard let w = vorschlag(nach: vorgaenger) else { return nil }
        guard eingetragen < w.tage else { return nil }
        return ZuKurz(eingetragen: eingetragen, katalog: w)
    }
}

// MARK: - Am Auftrag: welche Liegezeit davor ist zu kurz?

extension Auftrag {

    /// 🔴 Die zu kurzen Liegezeiten VOR diesem Auftrag.
    ///
    /// Es reicht nicht, beim Eintragen der Zahl etwas zu sagen — gesagt werden muss
    /// es dort, wo jemand **weitermacht**. Sonst steht der Hinweis in einer Karte,
    /// die beim Anfangen niemand offen hat, und am Ende heisst es doch:
    /// „der Mops wusste das, hat aber nichts gesagt."
    var zuKurzeLiegezeiten: [WartezeitKatalog.ZuKurz] {
        ((voraussetzungen as? Set<Voraussetzung>) ?? [])
            .compactMap { v in
                guard let quelle = v.quelle else { return nil }
                return WartezeitKatalog.pruefe(eingetragen: v.wartezeitTage,
                                               nach: Kausalkette.bezeichnung(quelle))
            }
            .sorted { $0.fehlendeTage > $1.fehlendeTage }
    }
}
