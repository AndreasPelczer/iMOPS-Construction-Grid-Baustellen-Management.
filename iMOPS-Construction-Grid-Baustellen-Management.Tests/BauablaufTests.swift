//
//  BauablaufTests.swift
//  Prüft den Bauablauf-Rang und die Reihenfolge-Prüfung — der Antwortschlüssel fürs
//  Sortier-Spiel des Lehrlings. Kette über Kausalkette.verknuepfe, kein Netz, keine UI.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BauablaufTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func auftrag(_ titel: String) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = titel
        return a
    }

    @MainActor
    private func verknuepfe(_ ziel: Auftrag, brauchtVorher quelle: Auftrag) throws {
        _ = try Kausalkette.verknuepfe(ziel, brauchtVorher: quelle, in: ctx)
    }

    @Test @MainActor func rangFolgtDerKette() throws {
        // a → b → c → d (linear)
        let a = auftrag("Baugrube ausheben")
        let b = auftrag("Schotter einbauen")
        let c = auftrag("Betonsohle gießen")
        let d = auftrag("Pflaster verlegen")
        try verknuepfe(b, brauchtVorher: a)
        try verknuepfe(c, brauchtVorher: b)
        try verknuepfe(d, brauchtVorher: c)

        let rang = Bauablauf.rang([d, c, b, a])   // Reihenfolge der Liste egal
        #expect(rang[a.objectID] == 0)
        #expect(rang[b.objectID] == 1)
        #expect(rang[c.objectID] == 2)
        #expect(rang[d.objectID] == 3)
    }

    @Test @MainActor func gueltigeReihenfolgeWirdErkannt() throws {
        let a = auftrag("Baugrube ausheben")
        let b = auftrag("Schotter einbauen")
        let c = auftrag("Betonsohle gießen")
        try verknuepfe(b, brauchtVorher: a)
        try verknuepfe(c, brauchtVorher: b)

        #expect(Bauablauf.istGueltigeReihenfolge([a, b, c]))     // richtig
        #expect(!Bauablauf.istGueltigeReihenfolge([b, a, c]))    // b vor a → falsch
        #expect(!Bauablauf.istGueltigeReihenfolge([a, c, b]))    // c vor b → falsch
        #expect(Bauablauf.ersterFehler([a, b, c]) == nil)
        #expect(Bauablauf.ersterFehler([b, a, c])?.objectID == a.objectID)
    }

    @Test @MainActor func paralleleSchritteBeideReihenfolgenGueltig() throws {
        // a zuerst; b und e hängen beide nur an a → gleicher Rang, beide Reihenfolgen ok
        let a = auftrag("Baustelle einrichten")
        let b = auftrag("Wasser legen")
        let e = auftrag("Strom legen")
        try verknuepfe(b, brauchtVorher: a)
        try verknuepfe(e, brauchtVorher: a)

        #expect(Bauablauf.istGueltigeReihenfolge([a, b, e]))
        #expect(Bauablauf.istGueltigeReihenfolge([a, e, b]))
        #expect(!Bauablauf.istGueltigeReihenfolge([b, a, e]))    // a muss vorne bleiben
    }
}
