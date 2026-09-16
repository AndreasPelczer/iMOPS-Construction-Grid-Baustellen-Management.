//
//  BaustelleGAEBTests.swift
//  „Baustelle aus GAEB": das LV hängt am Event, und Löschen der Baustelle nimmt es mit.
//  Genau die Garantie, auf die man sich verlässt: Auftrag nicht angenommen → beides weg.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaustelleGAEBTests {

    private let controller = PersistenceController(inMemory: true)
    @MainActor private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Baustelle mit LV anlegen → alles da; Baustelle löschen → LV per Cascade komplett weg.
    @Test @MainActor func baustelleLoeschenNimmtLVMit() throws {
        let event = Event(context: ctx)
        event.title = "Außenanlage aus GAEB"
        event.timeStamp = Date()
        for i in 1...5 {
            let p = LVPosition(context: ctx)
            p.posNr = "01.\(i)"
            p.bezeichnung = "Position \(i)"
            p.langtext = "Langtext \(i)"
            p.menge = Double(i) * 10
            p.einheit = "m"
            p.event = event
        }
        try ctx.save()

        // LV hängt an der Baustelle
        let vorher = try ctx.count(for: LVPosition.fetchRequest())
        #expect(vorher == 5)
        #expect(event.lvPositionen?.count == 5)

        // Baustelle löschen → Cascade räumt das LV ab
        ctx.delete(event)
        try ctx.save()

        let nachher = try ctx.count(for: LVPosition.fetchRequest())
        #expect(nachher == 0)
        let eventsUebrig = try ctx.count(for: Event.fetchRequest())
        #expect(eventsUebrig == 0)
    }

    /// Der Langtext aus dem GAEB landet auf der Position (fürs klappbare Nachlesen).
    @Test @MainActor func langtextBleibtAnDerPosition() throws {
        let event = Event(context: ctx)
        event.timeStamp = Date()
        let p = LVPosition(context: ctx)
        p.bezeichnung = "Rohrgraben herstellen"
        p.langtext = "Tiefe ca. 2,50 m, einschl. Verbau, Boden Kl. 3-4."
        p.event = event
        try ctx.save()
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        #expect(positionen.first?.langtext?.contains("Verbau") == true)
    }
}
