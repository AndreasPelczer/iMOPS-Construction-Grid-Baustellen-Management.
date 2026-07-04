//
//  HierarchieTests.swift
//  Welle 9 — Bau-Hierarchie (Stufe A): HierarchieHelfer.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct HierarchieTests {

    // Eigener isolierter In-Memory-Stack pro Test (Instanz-Property → pro @Test frisch),
    // siehe AufmassTests. Kein ctx.save() nötig — der Helfer arbeitet auf dem Objektgraph.
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func makeEvent(mitPositionen n: Int) -> Event {
        let e = Event(context: ctx)
        e.title = "Testbaustelle"
        for i in 0..<n {
            let p = LVPosition(context: ctx)
            p.posNr = "\(i)"
            p.menge = 1
            p.event = e
        }
        return e
    }

    /// Ohne Hierarchie: Helfer legt Gebäude+Geschoss an und hängt alle Positionen ein.
    @Test @MainActor func sichertDefaultGeschossUndOrdnetPositionenZu() {
        let e = makeEvent(mitPositionen: 3)
        #expect(HierarchieHelfer.defaultGeschoss(for: e) == nil)

        let ergebnis = HierarchieHelfer.sichereDefaultGeschoss(for: e, in: ctx)

        #expect(ergebnis.geaendert == true)
        #expect(ergebnis.geschoss.name == HierarchieHelfer.defaultGeschossName)
        #expect((e.gebaeude as? Set<Gebaeude>)?.count == 1)
        let positionen = (e.lvPositionen as? Set<LVPosition>) ?? []
        #expect(positionen.allSatisfy { $0.geschoss == ergebnis.geschoss })
    }

    /// Zweiter Aufruf ändert nichts und legt kein zweites Gebäude an.
    @Test @MainActor func istIdempotent() {
        let e = makeEvent(mitPositionen: 2)
        let erst = HierarchieHelfer.sichereDefaultGeschoss(for: e, in: ctx)
        let zweit = HierarchieHelfer.sichereDefaultGeschoss(for: e, in: ctx)

        #expect(zweit.geaendert == false)
        #expect(zweit.geschoss == erst.geschoss)
        #expect((e.gebaeude as? Set<Gebaeude>)?.count == 1)
    }

    /// Eine nachträglich (z.B. per Import) angelegte Position bekommt beim nächsten Lauf
    /// das bestehende Default-Geschoss — nie nil.
    @Test @MainActor func neuePositionWirdNachtraeglichZugeordnet() {
        let e = makeEvent(mitPositionen: 1)
        let g = HierarchieHelfer.sichereDefaultGeschoss(for: e, in: ctx).geschoss

        let neu = LVPosition(context: ctx)
        neu.posNr = "neu"; neu.menge = 1; neu.event = e
        #expect(neu.geschoss == nil)

        let ergebnis = HierarchieHelfer.sichereDefaultGeschoss(for: e, in: ctx)
        #expect(ergebnis.geaendert == true)
        #expect(neu.geschoss == g)
    }

    /// Stufe B: Anlegen vergibt aufsteigende reihenfolge; Abfragen sortieren korrekt.
    @Test @MainActor func anlegenUndReihenfolge() {
        let e = makeEvent(mitPositionen: 0)
        let hausA = HierarchieHelfer.neuesGebaeude(name: "Haus A", for: e, in: ctx)
        let hausB = HierarchieHelfer.neuesGebaeude(name: "Haus B", for: e, in: ctx)
        #expect(hausA.reihenfolge == 0)
        #expect(hausB.reihenfolge == 1)

        let eg = HierarchieHelfer.neuesGeschoss(name: "EG", in: hausA, context: ctx)
        let og = HierarchieHelfer.neuesGeschoss(name: "OG", in: hausA, context: ctx)
        #expect(eg.reihenfolge == 0)
        #expect(og.reihenfolge == 1)

        #expect(HierarchieHelfer.geschosse(of: hausA).map { $0.name } == ["EG", "OG"])
        #expect(HierarchieHelfer.alleGebaeude(for: e).count == 2)
        #expect(HierarchieHelfer.alleGeschosse(for: e).count == 2)
    }
}
