//
//  KennwertAusProjekten.swift
//
//  Der Rückweg: aus den eigenen Baustellen lernen, was ein Quadratmeter WIRKLICH kostet.
//
//  Der Hausplaner rechnet bisher alles aus EINER Zahl hoch — dem Kennwert je m²
//  (2.000 / 2.500 / 3.200 €) — und verteilt ihn nach festen Prozenten auf die Gewerke.
//  Diese Zahlen sind Vorgaben, also geraten. Das ist in Ordnung, solange man es weiß;
//  schlecht wird es, wenn eine geratene Zahl genauso aussieht wie eine gerechnete.
//
//  Hier entsteht die Gegenzahl: je Gewerk die Summe aus echten LVs, geteilt durch die
//  Wohnfläche des Projekts. `KennwertVergleich` macht das schon für EINE Baustelle
//  (Soll gegen Ist) — diese Datei dreht es um und fasst ALLE Baustellen zusammen.
//
//  Bewusst NICHT gebaut: ein Automatismus, der die Kennwerte still überschreibt. Was
//  hier herauskommt, wird angezeigt und kann übernommen werden. Ein Erfahrungswert aus
//  einem einzigen Projekt ist ein Hinweis, kein Gesetz — und das muss man sehen.
//

import Foundation
import CoreData

enum KennwertAusProjekten {

    /// Was ein Gewerk in den eigenen Projekten wirklich gekostet hat.
    struct Erfahrung {
        let topf: String            // "Rohbau", "Dach", … (Sprache von KennwertVergleich)
        let euroProQm: Double       // Summe aller Projekte / Summe aller Wohnflächen
        let projekte: Int           // aus wie vielen Baustellen
        let summe: Double           // absolut, über alle Projekte
        let flaeche: Double         // zugehörige Wohnfläche gesamt

        /// Ein Wert aus einem einzigen Projekt ist ein Anhaltspunkt, mehr nicht.
        var belastbar: Bool { projekte >= 3 }
        var herkunft: String {
            projekte == 1 ? "aus 1 eigenen Projekt"
                          : "aus \(projekte) eigenen Projekten"
        }
    }

    struct Ergebnis {
        let jeTopf: [String: Erfahrung]
        let projekte: Int           // Baustellen, die überhaupt zählbar waren
        let gesamtProQm: Double     // alle Gewerke zusammen
        let flaeche: Double

        var istLeer: Bool { projekte == 0 }
    }

    /// Liest alle Baustellen, die BEIDES haben: eine Wohnfläche aus dem Planer und
    /// LV-Positionen mit Preis. Ohne beides lässt sich kein €/m² bilden.
    @MainActor
    static func lerne(in ctx: NSManagedObjectContext) -> Ergebnis {
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        let events = (try? ctx.fetch(req)) ?? []

        var summeJeTopf: [String: Double] = [:]
        var flaecheJeTopf: [String: Double] = [:]
        var projekteJeTopf: [String: Int] = [:]
        var gesamtSumme = 0.0
        var gesamtFlaeche = 0.0
        var gezaehlt = 0

        for event in events {
            let extras = EventExtrasPayload.laden(aus: event)
            guard let projekt = extras.houseProject, projekt.wohnflaeche > 0 else { continue }

            let positionen = ((event.lvPositionen as? Set<LVPosition>) ?? [])
                .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
                .zaehlbarePositionen()
            guard !positionen.isEmpty else { continue }

            // Je Topf aufsummieren — dieselbe Zuordnung wie im Soll/Ist-Vergleich,
            // damit beide Seiten dieselbe Sprache sprechen.
            var jeTopfHier: [String: Double] = [:]
            for pos in positionen {
                guard let kg = pos.kostenGruppeNummer,
                      let topf = KennwertVergleich.topf(fuerKostengruppe: kg) else { continue }
                let betrag = LVKalkulator.effektiverEP(for: pos) * pos.menge
                guard betrag > 0 else { continue }
                jeTopfHier[topf, default: 0] += betrag
            }
            guard !jeTopfHier.isEmpty else { continue }

            gezaehlt += 1
            gesamtFlaeche += projekt.wohnflaeche
            for (topf, betrag) in jeTopfHier {
                summeJeTopf[topf, default: 0] += betrag
                flaecheJeTopf[topf, default: 0] += projekt.wohnflaeche
                projekteJeTopf[topf, default: 0] += 1
                gesamtSumme += betrag
            }
        }

        var jeTopf: [String: Erfahrung] = [:]
        for (topf, summe) in summeJeTopf {
            let flaeche = flaecheJeTopf[topf] ?? 0
            guard flaeche > 0 else { continue }
            jeTopf[topf] = Erfahrung(topf: topf,
                                     euroProQm: summe / flaeche,
                                     projekte: projekteJeTopf[topf] ?? 0,
                                     summe: summe,
                                     flaeche: flaeche)
        }

        return Ergebnis(jeTopf: jeTopf,
                        projekte: gezaehlt,
                        gesamtProQm: gesamtFlaeche > 0 ? gesamtSumme / gesamtFlaeche : 0,
                        flaeche: gesamtFlaeche)
    }

    /// Die Herkunft EINER Kostenzeile im Planer — das, was der Nutzer sehen soll.
    enum Herkunft {
        case ausProjekten(Erfahrung)        // wir haben echte Zahlen
        case geschaetzt(anteilProzent: Int) // reine Prozentverteilung des Kennwerts

        var kurz: String {
            switch self {
            case .ausProjekten(let e): return e.herkunft
            case .geschaetzt(let p):   return "geschätzt · \(p) % vom Kennwert"
            }
        }
        var istEcht: Bool {
            if case .ausProjekten = self { return true }
            return false
        }
    }

    /// Die festen Anteile aus `HouseProjectGenerator.berechneBaukosten` — hier nur, um
    /// dem Nutzer sagen zu können, WORAUS eine geschätzte Zeile entstanden ist.
    /// Ändern sich die Prozente dort, gehören sie hier nachgezogen.
    static let geschaetzteAnteile: [String: Int] = [
        "Rohbau": 28, "Dach": 8, "Fenster & Türen": 7, "Elektro": 10, "Sanitär": 8,
        "Heizung": 8, "Trockenbau": 5, "Estrich": 4, "Maler": 5, "Außenanlagen": 4
    ]

    /// Für eine Planer-Zeile: woher kommt die Zahl?
    static func herkunft(fuer topf: String, erfahrung: Ergebnis) -> Herkunft {
        if let e = erfahrung.jeTopf[topf], e.euroProQm > 0 {
            return .ausProjekten(e)
        }
        return .geschaetzt(anteilProzent: geschaetzteAnteile[topf] ?? 0)
    }
}
