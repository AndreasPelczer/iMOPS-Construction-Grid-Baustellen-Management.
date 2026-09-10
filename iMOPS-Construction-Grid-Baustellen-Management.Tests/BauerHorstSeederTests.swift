//
//  BauerHorstSeederTests.swift
//  Die Demo-Baustelle mit beiden Sichten — und der Lücke dazwischen.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BauerHorstSeederTests {

    // Instanz-Property, nicht inline: der Controller ist ein struct (siehe CLAUDE.md).
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func baustelle() throws -> Event {
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-PFOSTEN-001")
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func schritt(_ name: String, _ auftraege: [Auftrag]) throws -> Auftrag {
        try #require(auftraege.first { Kausalkette.bezeichnung($0).contains(name) })
    }

    // MARK: - Anlegen

    @Test @MainActor func zwoelfHandgriffeUndEineLVZeile() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        let auftraege = (event.jobs?.allObjects as? [Auftrag]) ?? []
        #expect(auftraege.count == 12)

        let positionen = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        #expect(positionen.count == 1)
    }

    /// Die Zahlen sind geschätzt — das muss die Position wissen, sonst führt die
    /// Welle-9-Ampel sie als gemessenen Wert.
    @Test @MainActor func dieLVZeileIstAlsSchaetzungMarkiertUndDurchgerechnet() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let pos = try #require((try baustelle().lvPositionen?.allObjects as? [LVPosition])?.first)

        #expect(pos.mengenQuelle == .schaetzung)
        #expect(pos.einheit == "psch")
        #expect(pos.menge == 1)

        // Ohne Einzelkosten wäre die Kalkulation leer und die Demo sinnlos.
        #expect((pos.kalkLohn?.count ?? 0) >= 1)
        #expect((pos.kalkMaterialien?.count ?? 0) >= 5)
        #expect((pos.kalkGeraete?.count ?? 0) >= 3)
    }

    // MARK: - Die Kette

    /// Der eigentliche Punkt der Demo: „Pfosten setzen" wartet auf **zwei** Stränge —
    /// das Kiesbett und den angemischten Beton. Ein Graph, keine Perlenkette.
    @Test @MainActor func pfostenSetzenWartetAufZweiStraenge() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        let pfosten = try schritt("Pfosten setzen", auftraege)
        let namen = Set(pfosten.vorgaenger.map(Kausalkette.bezeichnung))

        #expect(pfosten.vorgaenger.count == 2, "Vorgänger: \(namen)")
        #expect(namen.contains { $0.contains("Kiesbett") })
        #expect(namen.contains { $0.contains("Beton anmischen") })
    }

    @Test @MainActor func derErsteSchrittIstStartbarDerLetzteNicht() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        #expect(try schritt("Baustelle absichern", auftraege).istStartbar)
        #expect(try schritt("Räumen", auftraege).istStartbar == false)
    }

    /// Elf Kanten laut Drehbuch — wenn jemand die Liste ändert, soll es auffallen.
    @Test @MainActor func dieKetteHatDieErwartetenKanten() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let kanten = auftraege.flatMap { $0.voraussetzungenArray.filter(\.istKante) }

        #expect(kanten.count == 12)
        // Ein Kreis würde die ganze Kette unstartbar machen.
        #expect(auftraege.contains { $0.istStartbar })
    }

    // MARK: - Das Nicht-Ziel

    /// **Absicht, kein Versehen:** Die zwölf Aufträge und die eine LV-Zeile sind
    /// NICHT gekoppelt. Es gibt im Modell keine Beziehung zwischen `Auftrag` und
    /// `LVPosition`, und diese Demo führt genau diese Lücke vor. Der Test hält das
    /// fest, damit niemand sie „nebenbei" schließt.
    @Test @MainActor func auftraegeUndLVZeileBleibenUngekoppelt() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        let auftrag = try #require((event.jobs?.allObjects as? [Auftrag])?.first)
        let beziehungen = auftrag.entity.relationshipsByName.keys.sorted()

        #expect(!beziehungen.contains { $0.lowercased().contains("lvposition") },
                "Auftrag hat plötzlich eine LV-Beziehung: \(beziehungen)")
        // Beide hängen nur über die gemeinsame Baustelle zusammen.
        #expect(auftrag.event == event)
    }

    // MARK: - Idempotenz

    @Test @MainActor func zweiterLaufLegtNichtsDoppeltAn() throws {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        BauerHorstSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-PFOSTEN-001")
        #expect(try ctx.count(for: r) == 1)

        let event = try baustelle()
        #expect((event.jobs?.count ?? 0) == 12)
        #expect((event.lvPositionen?.count ?? 0) == 1)
    }
}
