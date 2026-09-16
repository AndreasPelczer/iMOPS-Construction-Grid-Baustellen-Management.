//
//  LVCanvasBrueckeTests.swift
//  Die Brücke Baustellen-LV ↔ Grap8-Canvas (Knoten = Auftrag), beide Richtungen,
//  idempotent über die vorhandene Beziehung Auftrag.lvPosition.
//
//  Wichtig: der neu erzeugte Auftrag muss speicherbar sein (Pflichtfelder gesetzt) —
//  ein „nackter" Auftrag crasht sonst save().
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LVCanvasBrueckeTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor private func baustelle() -> Event {
        let e = Event(context: ctx); e.title = "Testbaustelle"; return e
    }
    @MainActor private func position(_ bez: String, _ einheit: String = "m²",
                                     menge: Double = 10, event: Event) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = einheit; p.menge = menge; p.event = event
        return p
    }

    @Test @MainActor func lvAufDenCanvasErzeugtVerknuepfteKnotenUndSpeichert() throws {
        let e = baustelle()
        _ = position("Betonwände herstellen", event: e)
        _ = position("Oberboden abtragen", "m³", event: e)

        let neu = LVCanvasBruecke.lvAufDenCanvas(event: e, in: ctx)
        #expect(neu == 2)
        // Pflichtfelder gesetzt → save() darf NICHT crashen
        #expect(throws: Never.self) { try ctx.save() }
        // idempotent: zweiter Lauf legt nichts nach
        #expect(LVCanvasBruecke.lvAufDenCanvas(event: e, in: ctx) == 0)
    }

    @Test @MainActor func canvasInsLVErzeugtVerknuepftePosition() throws {
        let e = baustelle()
        let a = Auftrag(context: ctx)
        a.event = e; a.status = .pending; a.storageNote = ""
        a.processingDetails = "Pflaster verlegen"

        let neu = LVCanvasBruecke.canvasInsLV(event: e, in: ctx)
        #expect(neu == 1)
        #expect(a.lvPosition != nil)
        #expect(a.lvPosition?.bezeichnung == "Pflaster verlegen")
        #expect(throws: Never.self) { try ctx.save() }
        #expect(LVCanvasBruecke.canvasInsLV(event: e, in: ctx) == 0)   // idempotent
    }

    @Test @MainActor func keineDoppelWennSchonVerknuepft() throws {
        let e = baustelle()
        let p = position("Estrich", event: e)
        LVCanvasBruecke.erzeugeKnoten(fuer: p, event: e, in: ctx)   // schon verknüpft
        #expect(LVCanvasBruecke.lvAufDenCanvas(event: e, in: ctx) == 0)
    }
}
