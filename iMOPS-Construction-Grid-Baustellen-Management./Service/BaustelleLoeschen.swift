//
//  BaustelleLoeschen.swift
//
//  Andreas, 22.09.2026: „Wie lösche ich eine Baustelle richtig, damit nichts verwaist?"
//
//  🔴 Die ehrliche Antwort war: GAR NICHT. Es gab keinen richtigen Weg.
//
//  Im Datenmodell steht `Event.jobs` auf **Nullify**: beim Löschen einer Baustelle
//  wird bei jedem Auftrag nur die Verbindung gekappt, der Auftrag selbst bleibt.
//  Alles andere (lvPositionen, maengel, bautagesberichte) steht auf Cascade und geht
//  ordentlich mit. Also blieben bei jedem Löschen die Aufträge zurück — unsichtbar,
//  weil kein Bildschirm Aufträge ohne Baustelle zeigt.
//
//  Gemessen am 21.09.: 931 Waisen aus 23 gelöschten Baustellen, 323 verschiedene,
//  bis zu 23-mal dasselbe. Am 22.09. um 7:35 wurden es 965.
//
//  Das ist kein Bedienfehler. Niemand kann das richtig machen — deshalb wird hier
//  nicht gewarnt, sondern verhindert. (docs/WESEN-DES-MOPS.md, Regel 5:
//  Fehler dürfen gar nicht erst passieren können.)
//
//  Warum nicht einfach die Löschregel im Modell ändern? Weil das eine Migration
//  braucht und Andreas echte Daten drin hat. Der Code hier tut dasselbe, sofort und
//  ohne Risiko. Wird die Regel später auf Cascade gestellt, kann die Datei weg.
//

import Foundation
import CoreData
import os

enum BaustelleLoeschen {

    private static let logger = Logger(subsystem: "io.imops", category: "Loeschen")

    /// Was beim Löschen dieser Baustelle verschwindet — zum Anzeigen VOR der Tat.
    struct Folgen {
        var auftraege = 0
        var positionen = 0
        var maengel = 0
        var berichte = 0
        var kanten = 0

        var satz: String {
            var teile: [String] = []
            if auftraege > 0 { teile.append("\(auftraege) Arbeitspakete") }
            if positionen > 0 { teile.append("\(positionen) LV-Positionen") }
            if maengel > 0 { teile.append("\(maengel) Mängel") }
            if berichte > 0 { teile.append("\(berichte) Bautagesberichte") }
            return teile.isEmpty ? "Die Baustelle ist leer." : teile.joined(separator: " · ")
        }
    }

    @MainActor
    static func folgen(_ event: Event) -> Folgen {
        let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
        return Folgen(
            auftraege: jobs.count,
            positionen: ((event.lvPositionen as? Set<LVPosition>) ?? []).count,
            maengel: ((event.maengel as? Set<Mangel>) ?? []).count,
            berichte: ((event.bautagesberichte as? Set<Bautagesbericht>) ?? []).count,
            kanten: jobs.reduce(0) { $0 + (($1.voraussetzungen as? Set<Voraussetzung>) ?? []).count })
    }

    /// Löscht die Baustelle MIT allem, was an ihr hängt.
    ///
    /// 🔴 Die Aufträge zuerst und ausdrücklich — sonst kappt Core Data nur die
    /// Verbindung und lässt sie liegen. Die Voraussetzungs-Kanten gehen über die
    /// Cascade-Regel des Auftrags mit; die Nebenbücher (Paket-Zuordnung,
    /// Liegezeit-Belege) werden hier aufgeräumt, weil sie kein Core Data sind.
    @MainActor
    static func loesche(_ event: Event, in ctx: NSManagedObjectContext) {
        let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
        let name = event.title ?? "Baustelle"

        for job in jobs {
            PaketZuordnung.shared.vergessen(job)
            ctx.delete(job)
        }
        ctx.delete(event)

        logger.info("Baustelle gelöscht: \(name, privacy: .public) mit \(jobs.count) Aufträgen")
    }

    // MARK: - Aufräumen, was schon liegengeblieben ist

    /// Aufträge ohne Baustelle. Kein Bildschirm zeigt sie, und sie wachsen bei jedem
    /// Löschen weiter.
    @MainActor
    static func waisen(in ctx: NSManagedObjectContext) -> [Auftrag] {
        let req: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        req.predicate = NSPredicate(format: "event == nil")
        return (try? ctx.fetch(req)) ?? []
    }

    /// 🔴 Unwiderruflich. Nur nach ausdrücklicher Bestätigung aufrufen, und die
    /// Zahl vorher zeigen.
    @MainActor
    @discardableResult
    static func raeumeWaisenAuf(in ctx: NSManagedObjectContext) -> Int {
        let liste = waisen(in: ctx)
        for job in liste {
            PaketZuordnung.shared.vergessen(job)
            ctx.delete(job)
        }
        logger.info("Waisen aufgeräumt: \(liste.count)")
        return liste.count
    }
}
