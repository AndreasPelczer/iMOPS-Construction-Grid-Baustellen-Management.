//
//  LiegezeitSucher.swift
//
//  Woher kommt die Zahl? — der Mops sucht sie selbst.
//
//  Andreas, Nacht 21./22.09.2026: „Wir brauchen immer eine dokumentierte und belegte
//  Zahl für die Wartezeit. Die kann aus folgenden Quellen kommen: Dokument, Fundus,
//  Internet … wenn eine Auswahl besteht, entscheidet der Mensch."
//  Und gleich darauf, auf Rückfrage: „ok, ohne Internet."
//
//  🔴 Die Rangfolge ist keine Geschmacksfrage, sie folgt daraus, wie nah eine Quelle
//  an DIESER Baustelle ist:
//
//      1. Dokument  — Lieferschein/Datenblatt des tatsächlich gelieferten Materials
//      2. Statik    — für dieses Bauteil verbindlich
//      3. Fundus    — was auf dem eigenen Server steht, schon einmal abgenommen
//      4. Katalog   — Richtwert ohne Kenntnis der Baustelle
//
//  Kein Internet: eine Netz-Zahl belegt nichts, weil niemand prüfen kann, ob es
//  dasselbe Produkt ist. Bestätigt sie ein Mensch, ist ER der Beleg, nicht die Seite.
//
//  🔴 Und die wichtigste Regel: **widersprechen sich die Quellen, sagt der Mops das.**
//  Er nimmt nicht heimlich die erste. Sonst sind wir wieder bei „er wusste es und
//  hat nichts gesagt" (docs/WESEN-DES-MOPS.md, Regeln 7 und 8).
//

import Foundation
import CoreData
import os

// MARK: - Ein Kandidat

struct LiegezeitKandidat: Identifiable, Equatable {
    var id: String { "\(herkunft.rawValue)|\(tage)|\(quelle)" }

    let tage: Double
    let herkunft: LiegezeitHerkunft
    /// Der Beleg selbst — „Lieferschein 19.09., CEM I 42,5 R" oder „Statik Pos. 4.3".
    let quelle: String
    /// Was der Mops dazu weiss, wörtlich. Bei Fundus-Antworten der Satz des Servers.
    var hinweis: String = ""

    /// Je kleiner, desto näher an dieser Baustelle.
    var rang: Int {
        switch herkunft {
        case .datenblatt:  return 0
        case .statiker:    return 1
        case .erfahrung:   return 2
        case .katalog:     return 3
        case .entschieden: return 4
        }
    }
}

// MARK: - Die Suche

enum LiegezeitSucher {

    private static let logger = Logger(subsystem: "io.imops", category: "Liegezeit")

    struct Ergebnis: Equatable {
        var kandidaten: [LiegezeitKandidat] = []
        /// Konnte der Fundus nicht gefragt werden? Dann steht das dabei — ein
        /// stiller Ausfall sähe aus wie „es gibt nichts".
        var fundusFehler: String?

        var beste: LiegezeitKandidat? { kandidaten.first }

        /// 🔴 Nennen zwei Quellen verschiedene Zahlen? Dann muss der Mensch ran.
        /// Toleranz: ein halber Tag — darunter ist es dieselbe Aussage.
        var widersprechenSich: Bool {
            guard let kleinste = kandidaten.map(\.tage).min(),
                  let groesste = kandidaten.map(\.tage).max() else { return false }
            return groesste - kleinste > 0.5
        }

        var satz: String {
            if kandidaten.isEmpty { return "Keine belegte Zahl gefunden." }
            if widersprechenSich {
                return "\(kandidaten.count) Quellen, und sie sind sich nicht einig. Du entscheidest."
            }
            return kandidaten.count == 1
                ? "Eine Quelle." : "\(kandidaten.count) Quellen, alle einig."
        }
    }

    /// Alles zusammentragen, was über die Liegezeit nach dieser Arbeit bekannt ist.
    ///
    /// Der Fundus wird nur gefragt, wenn `mitFundus` gesetzt ist — er kostet Zeit
    /// (CPU-only, bis zu 180 s) und soll nicht bei jedem Neuzeichnen anlaufen.
    @MainActor
    static func suche(nach vorgaenger: String,
                      event: Event?,
                      mitFundus: Bool = false) async -> Ergebnis {
        var e = Ergebnis()

        // 1. + 2. Dokumente und Statik dieser Baustelle
        e.kandidaten += ausDokumenten(event: event, arbeit: vorgaenger)

        // 4. Der eigene Richtwert — immer dabei, aber als das, was er ist.
        if let w = WartezeitKatalog.vorschlag(nach: vorgaenger) {
            e.kandidaten.append(LiegezeitKandidat(
                tage: w.tage, herkunft: .katalog,
                quelle: w.quelleKurz, hinweis: w.hinweis))
        }

        // 3. Der Fundus — der eigene Server, gefragt wie bei den Arbeitsschritten.
        if mitFundus {
            do {
                if let k = try await ausDemFundus(arbeit: vorgaenger) {
                    e.kandidaten.append(k)
                }
            } catch {
                e.fundusFehler = error.localizedDescription
                logger.error("Fundus nicht erreichbar: \(error.localizedDescription, privacy: .public)")
            }
        }

        e.kandidaten.sort { $0.rang < $1.rang }
        return e
    }

    // MARK: - Dokumente dieser Baustelle

    /// 🔴 Noch ein Gerüst: die Dokumentauswertung (`/extract-doc`) kennt keinen
    /// Doctype „Datenblatt", also findet sie auch keine Liegezeiten. Was hier
    /// gelesen wird, sind bereits gespeicherte Auswertungen — sobald der Server
    /// so ein Feld liefert, kommt es ohne weitere Arbeit hier an.
    @MainActor
    private static func ausDokumenten(event: Event?, arbeit: String) -> [LiegezeitKandidat] {
        guard let event else { return [] }
        let payload = EventExtrasPayload.laden(aus: event)
        var gefunden: [LiegezeitKandidat] = []

        for a in payload.auswertungen ?? [] {
            let r = a.ergebnis
            guard let tage = tageAusFeldern(r.felder) else { continue }
            let istStatik = r.doctypeErkannt.lowercased().contains("statik")
            gefunden.append(LiegezeitKandidat(
                tage: tage,
                herkunft: istStatik ? .statiker : .datenblatt,
                quelle: r.quelle,
                hinweis: r.meldung))
        }
        return gefunden
    }

    /// Sucht in den Feldern einer Auswertung nach einer Liegezeit in Tagen.
    /// Bewusst eng: nur Felder, deren Name die Sache benennt — nicht jede Zahl.
    static func tageAusFeldern(_ felder: JSONValue?) -> Double? {
        guard case .object(let dict)? = felder else { return nil }
        let schluessel = ["wartezeit_tage", "liegezeit_tage", "trocknungszeit_tage",
                          "aushaertezeit_tage", "ausschalfrist_tage"]
        for s in schluessel {
            if case .number(let n)? = dict[s], n > 0 { return n }
            if case .string(let t)? = dict[s], let n = Double(t.replacingOccurrences(of: ",", with: ".")), n > 0 {
                return n
            }
        }
        return nil
    }

    // MARK: - Der Fundus

    /// Die Frage an den eigenen Server. Sie verlangt eine Zahl UND ihre Herkunft —
    /// eine Zahl ohne Quelle wäre nur eine weitere Behauptung.
    static func fundusFrage(arbeit: String) -> String {
        """
        Liegezeit auf der Baustelle.

        Arbeit: \(arbeit)

        Wie viele Tage muss danach gewartet werden, bevor der nächste Arbeitsschritt
        beginnen kann (Aushärten, Trocknen, Abbinden)?

        Antworte in GENAU zwei Zeilen:
        TAGE: <Zahl>
        QUELLE: <woher der Wert stammt, kurz>

        Wenn du es nicht sicher weisst, antworte nur mit:
        TAGE: unbekannt
        """
    }

    /// Liest „TAGE: 3" aus der Antwort. Alles andere wird verworfen — lieber kein
    /// Kandidat als ein aus Prosa geratener.
    static func kandidatAus(_ antwort: String) -> LiegezeitKandidat? {
        let zeilen = antwort.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var tage: Double?
        var quelle = "Fundus"

        for z in zeilen {
            let klein = z.lowercased()
            if klein.hasPrefix("tage:") {
                let rest = z.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: ".")
                if let zahl = Double(rest.prefix(while: { $0.isNumber || $0 == "." })) , zahl > 0 {
                    tage = zahl
                }
            } else if klein.hasPrefix("quelle:") {
                let rest = z.dropFirst(7).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { quelle = String(rest.prefix(80)) }
            }
        }
        guard let tage else { return nil }
        return LiegezeitKandidat(tage: tage, herkunft: .erfahrung,
                                 quelle: "Fundus — \(quelle)",
                                 hinweis: "Vom eigenen Server. Noch von niemandem abgenommen.")
    }

    private static func ausDemFundus(arbeit: String) async throws -> LiegezeitKandidat? {
        let antwort = try await MopsClient().ask(question: fundusFrage(arbeit: arbeit),
                                                      useProf: true)
        return kandidatAus(antwort.answer)
    }
}
