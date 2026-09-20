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

    // MARK: - Zeit im Canvas (Vorwärtsrechnung, rein — kein Core Data nötig)

    /// Betonieren (1) → 3 Tage härten (Kante) → Ausschalen (1) → Anschluss (2).
    @Test func haertezeitAufDerKanteVerschiebt() {
        let knoten = [
            AblaufKnoten(id: "beton", name: "Betonieren", dauerTage: 1),
            AblaufKnoten(id: "schal", name: "Ausschalen", dauerTage: 1),
            AblaufKnoten(id: "anschluss", name: "Anschlussarbeit", dauerTage: 2),
        ]
        let kanten = [
            AblaufKante(von: "beton", zu: "schal", wartezeitTage: 3),   // härten
            AblaufKante(von: "schal", zu: "anschluss", wartezeitTage: 0),
        ]
        let r = Bauablauf.vorwaertsrechnung(knoten: knoten, kanten: kanten)
        let t = Dictionary(uniqueKeysWithValues: r.termine.map { ($0.knotenID, $0) })
        #expect(t["beton"]?.fruehestesEndeTag == 1)
        #expect(t["schal"]?.fruehesterStartTag == 4)   // EF(beton)=1 + 3 härten
        #expect(t["anschluss"]?.fruehestesEndeTag == 7)
        #expect(r.gesamtdauerTage == 7)
        #expect(r.zyklus.isEmpty)
    }

    /// Ein Nachfolger, der auf zwei Vorgänger wartet, startet nach dem SPÄTEREN.
    @Test func parallelNimmtDenSpaeteren() {
        let knoten = [
            AblaufKnoten(id: "a", name: "A", dauerTage: 2),
            AblaufKnoten(id: "b", name: "B", dauerTage: 5),
            AblaufKnoten(id: "c", name: "C", dauerTage: 1),
        ]
        let kanten = [
            AblaufKante(von: "a", zu: "c", wartezeitTage: 0),
            AblaufKante(von: "b", zu: "c", wartezeitTage: 0),
        ]
        let r = Bauablauf.vorwaertsrechnung(knoten: knoten, kanten: kanten)
        #expect(r.termine.first { $0.knotenID == "c" }?.fruehesterStartTag == 5)
    }

    /// Ringabhängigkeit → ehrlich als Zyklus gemeldet, keine (falschen) Termine.
    @Test func zyklusWirdErkannt() {
        let knoten = [
            AblaufKnoten(id: "x", name: "X", dauerTage: 1),
            AblaufKnoten(id: "y", name: "Y", dauerTage: 1),
        ]
        let kanten = [
            AblaufKante(von: "x", zu: "y", wartezeitTage: 0),
            AblaufKante(von: "y", zu: "x", wartezeitTage: 0),
        ]
        let r = Bauablauf.vorwaertsrechnung(knoten: knoten, kanten: kanten)
        #expect(!r.zyklus.isEmpty)
        #expect(r.termine.isEmpty)
    }
}
