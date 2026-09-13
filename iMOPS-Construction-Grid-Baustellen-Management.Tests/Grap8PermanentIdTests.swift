//
//  Grap8PermanentIdTests.swift
//  DRINGEND-Fix: der Grap8-Absturz auf temporären Core-Data-IDs.
//
//  Ein frisch angelegter, ungespeicherter Auftrag hat eine TEMPORÄRE objectID (`n-…`).
//  Deren uriRepresentation ist keine gültige Core-Data-URI und ließ die Web-Brücke
//  abstürzen. `Grap8Graph.aus(_:)` holt jetzt an der Wurzel permanente IDs, bevor die
//  URIs zu Knoten-Kennungen werden. Dieser Test hält das fest, ohne die App zu starten.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct Grap8PermanentIdTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test @MainActor func ausHoltPermanenteIdsUndKennungIstGueltigeUri() throws {
        let event = Event(context: ctx)
        event.name = "Testbaustelle"

        let auftrag = Auftrag(context: ctx)
        auftrag.processingDetails = "Baustelle absichern"
        auftrag.status = .pending          // Pflichtfeld statusRawValue
        auftrag.storageNote = ""           // Pflichtfeld
        auftrag.event = event

        // Vorbedingung: OHNE Speichern ist die ID temporär (genau der Crash-Auslöser).
        #expect(auftrag.objectID.isTemporaryID, "Testaufbau falsch — ID war schon permanent.")

        // Der Graph-Aufbau muss die ID an der Wurzel permanent machen.
        let graph = Grap8Graph.aus(event)

        #expect(!auftrag.objectID.isTemporaryID, "aus() hat keine permanente ID geholt.")
        let knoten = try #require(graph.nodes.first)
        // Die Kennung ist jetzt eine gültige Core-Data-URI, kein temporäres n-…
        #expect(knoten.id.hasPrefix("x-coredata://"),
                "Kennung ist keine permanente URI: \(knoten.id)")
        #expect(!knoten.id.hasPrefix("n-"))
    }

    // MARK: - Leitstand: die Chips spiegeln die Kalkulation

    @Test @MainActor func chipsSpiegelnDieKalkulation() throws {
        let event = Event(context: ctx)
        event.name = "Testbaustelle"
        let auftrag = Auftrag(context: ctx)
        auftrag.processingDetails = "Baustelle absichern"
        auftrag.status = .pending
        auftrag.storageNote = ""
        auftrag.event = event

        func chip(_ typ: String, _ nodes: [Grap8Graph.Knoten]) -> Bool? {
            nodes.first?.data.anf.first { $0.typ == typ }?.erfuellt
        }

        // Ohne eigene Position: alle drei Chips offen.
        let leer = Grap8Graph.aus(event).nodes
        #expect(chip("material", leer) == false)
        #expect(chip("mensch", leer) == false)
        #expect(chip("maschine", leer) == false)

        // Position mit Lohn → „Mannschaft" erfüllt, Material/Maschine bleiben offen.
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Baustelle absichern"
        pos.menge = 1
        pos.einheit = "psch"
        pos.event = event
        auftrag.lvPosition = pos
        let pl = PositionLohn(context: ctx)
        pl.id = UUID()
        pl.qualifikation = "Maurer"
        pl.stunden = 0.5
        pl.position = pos

        let mit = Grap8Graph.aus(event).nodes
        #expect(chip("mensch", mit) == true, "Lohn ist da → Mannschaft-Chip muss erfüllt sein.")
        #expect(chip("material", mit) == false)
        #expect(chip("maschine", mit) == false)
    }
}
