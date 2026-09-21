//
//  SonderfallBuch.swift
//
//  Der „Jaaa, das musst du so sehen"-Knopf.
//
//  Andreas, 21.09.2026: „wir brauchen einen ‚jaaa, des musst du so sehen' button …
//  in den Gesprächen mit Raphi kommt das zu oft vor, um es als Regelwerk in den Mops
//  aufzunehmen. Können wir damit was anfangen? War gerade so ein Gehirnfurz, aber die
//  sind manchmal gut."
//
//  Konnten wir. Der Knopf macht zwei Dinge, und das zweite ist das eigentliche:
//
//  1. SOFORT: der Mops hört auf, diese eine Sache zu melden. Mit der Erklärung dran,
//     nicht stumm. Wer später fragt „warum steht da nichts von einer Dauer", findet
//     den Satz und den Namen dessen, der ihn geschrieben hat.
//
//  2. 🔴 AUF DAUER: der Mops ZÄHLT. Eine Ausnahme ist eine Ausnahme. Dieselbe
//     Ausnahme zum dritten Mal ist keine mehr — dann fehlt eine Regel. Genau das
//     Problem, das Andreas beschreibt: „zu oft, um es als Regelwerk aufzunehmen"
//     lässt sich nicht im Kopf sortieren, aber zählen kann eine Maschine.
//     Ab dem dritten Mal fragt der Mops: soll das eine Regel werden?
//
//  Der Unterschied zur `Uebergehung`: die sagt „ich mache trotzdem weiter und
//  unterschreibe das". Hier sagt jemand „du liegst hier falsch, und zwar deshalb".
//  Das eine ist Verantwortung, das andere ist Wissen.
//
//  Wie der AnweisungsKatalog: eine JSON-Datei, kein Core Data, keine Migration —
//  und später als eine Datei an Raphi zu geben.
//

import Foundation
import os

// MARK: - Ein erklärter Sonderfall

struct Sonderfall: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString

    /// Worum ging es? Ein kurzer, WIEDERERKENNBARER Schlüssel — daran wird gezählt.
    /// Zum Beispiel "dauer-fehlt" oder "nicht-im-lv:Bauzaun".
    var thema: String

    /// Was der Mops behauptet hat, wörtlich. Damit man den Satz später wiederfindet.
    var wasDerMopsSagte: String

    /// Was in Wirklichkeit gilt — der Satz, um den es geht.
    var wasGilt: String

    /// Wo es auffiel. Eine Erklärung ohne Ort ist schwer zu prüfen.
    var baustelle: String
    var betrifft: String

    var von: String
    var am: Date = Date()

    /// Gilt die Erklärung nur hier, oder immer? Andreas' Unterscheidung:
    /// manches ist baustellenabhängig, manches ist einfach so.
    var nurHier: Bool = true
}

// MARK: - Das Buch

final class SonderfallBuch {

    static let shared = SonderfallBuch()
    private let logger = Logger(subsystem: "io.imops", category: "Sonderfaelle")

    /// Ab wann eine Ausnahme keine mehr ist.
    static let regelSchwelle = 3

    private var faelle: [Sonderfall] = []
    private let datei: URL

    private init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datei = ordner.appendingPathComponent("sonderfaelle.json")
        laden()
    }

    // MARK: Schreiben

    @discardableResult
    func eintragen(_ fall: Sonderfall) -> Int {
        faelle.append(fall)
        sichern()
        let n = anzahl(thema: fall.thema)
        logger.info("Sonderfall: \(fall.thema, privacy: .public) — \(n). Mal")
        return n
    }

    // MARK: Lesen

    /// Wie oft wurde dieses Thema schon erklärt?
    func anzahl(thema: String) -> Int {
        faelle.filter { $0.thema == thema }.count
    }

    /// Gilt für diesen Fall eine Erklärung — schweigt der Mops hier also?
    ///
    /// „nurHier" zählt nur auf derselben Baustelle und für dasselbe Ding; eine
    /// Erklärung, die überall gilt, zählt immer.
    func erklaerung(thema: String, baustelle: String, betrifft: String) -> Sonderfall? {
        faelle.last {
            $0.thema == thema
            && (!$0.nurHier || ($0.baustelle == baustelle && $0.betrifft == betrifft))
        }
    }

    /// Themen, die oft genug erklärt wurden, um eine Regel zu verdienen —
    /// mit der Anzahl, absteigend.
    func reifeThemen() -> [(thema: String, anzahl: Int, letzte: Sonderfall)] {
        Dictionary(grouping: faelle, by: \.thema)
            .filter { $0.value.count >= Self.regelSchwelle }
            .compactMap { thema, liste in
                guard let letzte = liste.max(by: { $0.am < $1.am }) else { return nil }
                return (thema, liste.count, letzte)
            }
            .sorted { $0.anzahl > $1.anzahl }
    }

    var alle: [Sonderfall] { faelle.sorted { $0.am > $1.am } }

    // MARK: Datei

    private func laden() {
        guard let data = try? Data(contentsOf: datei) else { return }
        faelle = (try? JSONDecoder().decode([Sonderfall].self, from: data)) ?? []
    }

    private func sichern() {
        do {
            let data = try JSONEncoder().encode(faelle)
            try data.write(to: datei, options: .atomic)
        } catch {
            logger.error("Sonderfälle nicht gesichert: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Für Tests.
    func leeren() {
        faelle = []
        try? FileManager.default.removeItem(at: datei)
    }
}
