//
//  LoeschUndoTests.swift
//  „Command-Z im Mops": ein versehentlich gelöschtes Kästchen (Auftrag) muss sich
//  rückgängig machen lassen. Hält fest, dass der Core-Data-Undo den gelöschten Auftrag
//  zurückholt — genau, was der „Rückgängig"-Knopf in EventDetailView tut.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LoeschUndoTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test @MainActor func geloeschterAuftragKommtMitUndoZurueck() throws {
        // Der In-Memory-Controller setzt bewusst keinen Undo-Manager — hier selbst setzen,
        // wie es die App im echten Store tut.
        ctx.undoManager = UndoManager()

        let event = Event(context: ctx)
        event.name = "Testbaustelle"
        let auftrag = Auftrag(context: ctx)
        auftrag.processingDetails = "Kästchen"
        auftrag.status = .pending
        auftrag.storageNote = ""
        auftrag.event = event
        try ctx.save()

        // Sauberer Start: nur das Löschen soll rückgängig gehen (nicht das Anlegen).
        ctx.undoManager?.removeAllActions()

        // Löschen wie im Kontextmenü.
        ctx.delete(auftrag)
        try ctx.save()
        #expect(auftraege(event).isEmpty, "Nach dem Löschen darf kein Auftrag mehr da sein.")

        // „Rückgängig".
        ctx.undoManager?.undo()
        try ctx.save()

        let zurueck = auftraege(event)
        #expect(zurueck.count == 1, "Der gelöschte Auftrag muss wieder da sein.")
        #expect(zurueck.first?.processingDetails == "Kästchen")
    }

    @MainActor
    private func auftraege(_ event: Event) -> [Auftrag] {
        (event.jobs?.allObjects as? [Auftrag]) ?? []
    }
}
