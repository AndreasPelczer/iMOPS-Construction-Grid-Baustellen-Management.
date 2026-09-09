//
//  KausalketteTests.swift
//  Grap8 Branch 1 — Schritt→Schritt-Abhängigkeiten.
//
//  „Ohne Topf aufsetzen und Wasser erhitzen kann ich keine Nudeln kochen.“
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct KausalketteTests {

    // Instanz-Property, nicht inline: der Controller ist ein struct — inline
    // erzeugt gäbe er den Container sofort wieder frei (siehe CLAUDE.md).
    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// `statusRawValue` und `storageNote` sind im Modell nicht optional — beide
    /// setzen, damit ein späteres `save()` nicht an der Validierung scheitert.
    @MainActor
    private func macheAuftrag(_ bezeichnung: String) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = bezeichnung
        a.status = .pending
        a.storageNote = ""
        return a
    }

    // MARK: - Lösen

    @Test @MainActor func entknuepfenGibtDenSchrittFrei() throws {
        let wasser = macheAuftrag("Wasser erhitzen")
        let nudeln = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(nudeln, brauchtVorher: wasser, in: ctx)
        #expect(nudeln.istStartbar == false)

        let geloest = Kausalkette.entknuepfe(nudeln, brauchtNichtMehr: wasser, in: ctx)

        #expect(geloest == true)
        #expect(nudeln.voraussetzungenArray.isEmpty)
        #expect(nudeln.istStartbar == true)
        // Auch die Gegenrichtung muss leer sein, sonst bliebe eine halbe Kante stehen.
        #expect(wasser.istVoraussetzungFuerArray.isEmpty)
    }

    @Test @MainActor func entknuepfenOhneKanteMeldetFalse() throws {
        let a = macheAuftrag("A")
        let b = macheAuftrag("B")

        #expect(Kausalkette.entknuepfe(a, brauchtNichtMehr: b, in: ctx) == false)
    }

    /// Nach dem Lösen aus der Mitte darf keine Lücke bleiben: `verknuepfe` zieht
    /// die nächste `reihenfolge` aus `count` — bei einer Lücke käme eine Nummer
    /// heraus, die es schon gibt, und zwei Kanten stritten um denselben Platz.
    @Test @MainActor func reihenfolgeBleibtLueckenlos() throws {
        let ziel = macheAuftrag("Nudeln kochen")
        let a = macheAuftrag("Wasser erhitzen")
        let b = macheAuftrag("Topf aufsetzen")
        let c = macheAuftrag("Salz holen")
        try Kausalkette.verknuepfe(ziel, brauchtVorher: a, in: ctx)
        try Kausalkette.verknuepfe(ziel, brauchtVorher: b, in: ctx)
        try Kausalkette.verknuepfe(ziel, brauchtVorher: c, in: ctx)

        // Die mittlere lösen.
        Kausalkette.entknuepfe(ziel, brauchtNichtMehr: b, in: ctx)

        #expect(ziel.voraussetzungenArray.map(\.reihenfolge) == [0, 1])

        // Und eine neue dazu: sie darf keine Nummer doppelt vergeben.
        let d = macheAuftrag("Sieb bereitstellen")
        try Kausalkette.verknuepfe(ziel, brauchtVorher: d, in: ctx)

        #expect(ziel.voraussetzungenArray.map(\.reihenfolge) == [0, 1, 2])
        #expect(ziel.vorgaenger.count == 3)
    }

    /// Ein manuelles Geschoss-Häkchen (Welle 9) ist keine Graph-Kante — `entknuepfe`
    /// darf es nicht anfassen, auch nicht versehentlich.
    @Test @MainActor func manuellesHaekchenBleibtUnberuehrt() throws {
        let ziel = macheAuftrag("Nudeln kochen")
        let quelle = macheAuftrag("Wasser erhitzen")

        let haekchen = Voraussetzung(context: ctx)
        haekchen.id = UUID()
        haekchen.name = "Abnahme durch den Polier"
        haekchen.typ = VoraussetzungsTyp.manuell.rawValue
        haekchen.erfuellt = false
        haekchen.reihenfolge = 0
        haekchen.auftrag = ziel

        try Kausalkette.verknuepfe(ziel, brauchtVorher: quelle, in: ctx)
        Kausalkette.entknuepfe(ziel, brauchtNichtMehr: quelle, in: ctx)

        // Die Kante ist weg, das Häkchen steht noch.
        #expect(ziel.voraussetzungenArray.count == 1)
        #expect(ziel.voraussetzungenArray.first?.istKante == false)
        #expect(ziel.voraussetzungenArray.first?.name == "Abnahme durch den Polier")
    }

    // MARK: - Der Nudel-Test

    @Test @MainActor func nudelnWartenAufWasser() throws {
        let wasser = macheAuftrag("Wasser erhitzen")
        let nudeln = macheAuftrag("Nudeln kochen")

        try Kausalkette.verknuepfe(nudeln, brauchtVorher: wasser, in: ctx)

        #expect(nudeln.istStartbar == false)
        #expect(nudeln.offeneVoraussetzungen.count == 1)
        #expect(nudeln.vorgaenger.first === wasser)
        // Wasser selbst hängt von nichts ab — es darf sofort los.
        #expect(wasser.istStartbar == true)
        #expect(wasser.istVoraussetzungFuerArray.count == 1)

        wasser.status = .completed

        #expect(nudeln.istStartbar == true)
        #expect(nudeln.offeneVoraussetzungen.isEmpty)
    }

    /// Früher zählte hier eine ODER-Krücke über `isCompleted` UND `status`, weil
    /// die zwei Felder auseinanderliefen. Seit `Auftrag.istFertig` gibt es eine
    /// Quelle — der Status. Das Legacy-Feld zieht der Setter mit.
    @Test @MainActor func derStatusGibtDenNachfolgerFrei() throws {
        let wasser = macheAuftrag("Wasser erhitzen")
        let nudeln = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(nudeln, brauchtVorher: wasser, in: ctx)

        #expect(nudeln.istStartbar == false)
        wasser.status = .completed
        #expect(wasser.isCompleted == true, "Das Legacy-Feld muss mitgezogen werden.")
        #expect(nudeln.istStartbar == true)
    }

    @Test @MainActor func ohneVoraussetzungSofortStartbar() {
        let topf = macheAuftrag("Topf aufsetzen")
        #expect(topf.istStartbar == true)
        #expect(topf.voraussetzungenArray.isEmpty)
    }

    @Test @MainActor func mehrereVoraussetzungenAlleNoetig() throws {
        let topf = macheAuftrag("Topf aufsetzen")
        let salz = macheAuftrag("Salzen")
        let nudeln = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(nudeln, brauchtVorher: topf, in: ctx)
        try Kausalkette.verknuepfe(nudeln, brauchtVorher: salz, in: ctx)

        #expect(nudeln.offeneVoraussetzungen.count == 2)
        topf.status = .completed
        #expect(nudeln.istStartbar == false)          // einer reicht nicht
        #expect(nudeln.offeneVoraussetzungen.count == 1)
        salz.status = .completed
        #expect(nudeln.istStartbar == true)
    }

    // MARK: - Kein Zyklus

    @Test @MainActor func direkterZyklusWirdAbgelehnt() throws {
        let a = macheAuftrag("Wasser erhitzen")
        let b = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(b, brauchtVorher: a, in: ctx)

        #expect(throws: KausalketteFehler.self) {
            try Kausalkette.verknuepfe(a, brauchtVorher: b, in: ctx)
        }
        // Abgelehnt heißt: der Graph ist unverändert geblieben.
        #expect(a.voraussetzungenArray.isEmpty)
        #expect(b.voraussetzungenArray.count == 1)
    }

    @Test @MainActor func transitiverZyklusWirdAbgelehnt() throws {
        let a = macheAuftrag("Schalung stellen")
        let b = macheAuftrag("Bewehrung legen")
        let c = macheAuftrag("Beton gießen")
        try Kausalkette.verknuepfe(b, brauchtVorher: a, in: ctx)
        try Kausalkette.verknuepfe(c, brauchtVorher: b, in: ctx)

        // a würde über b und c wieder auf sich selbst zeigen
        #expect(throws: KausalketteFehler.self) {
            try Kausalkette.verknuepfe(a, brauchtVorher: c, in: ctx)
        }
        #expect(a.voraussetzungenArray.isEmpty)
    }

    @Test @MainActor func selbstbezugWirdAbgelehnt() {
        let a = macheAuftrag("Wasser erhitzen")
        #expect(throws: KausalketteFehler.self) {
            try Kausalkette.verknuepfe(a, brauchtVorher: a, in: ctx)
        }
        #expect(a.voraussetzungenArray.isEmpty)
    }

    /// Der Sinn der Ablehnung: eine erlaubte Kette bleibt startbar-berechenbar,
    /// bei einem Kreis käme keiner der Beteiligten je dran.
    @Test @MainActor func ketteBleibtBerechenbar() throws {
        let a = macheAuftrag("Schalung stellen")
        let b = macheAuftrag("Bewehrung legen")
        let c = macheAuftrag("Beton gießen")
        try Kausalkette.verknuepfe(b, brauchtVorher: a, in: ctx)
        try Kausalkette.verknuepfe(c, brauchtVorher: b, in: ctx)

        #expect(a.istStartbar == true)
        #expect(b.istStartbar == false)
        #expect(c.istStartbar == false)

        a.status = .completed
        #expect(b.istStartbar == true)
        #expect(c.istStartbar == false)   // b ist noch nicht fertig

        b.status = .completed
        #expect(c.istStartbar == true)
    }

    // MARK: - Rückwärtskompatibilität

    /// Eine Voraussetzung ohne `quelle` ist weiter das manuelle Geschoss-Häkchen
    /// aus Welle 9 und richtet sich allein nach dem gespeicherten `erfuellt`.
    @Test @MainActor func geschossVoraussetzungOhneQuelleUnveraendert() {
        let geschoss = Geschoss(context: ctx)
        geschoss.name = "EG"

        let v = Voraussetzung(context: ctx)
        v.id = UUID()
        v.name = "Baugenehmigung liegt vor"
        v.typ = VoraussetzungsTyp.manuell.rawValue
        v.erfuellt = false
        v.geschoss = geschoss

        #expect(v.istKante == false)
        #expect(v.istErfuellt == false)

        v.erfuellt = true
        #expect(v.istErfuellt == true)

        // Sie hängt an keinem Auftrag und blockiert daher auch keinen.
        #expect(v.auftrag == nil)
        #expect(geschoss.voraussetzungenArray.count == 1)
    }

    /// Die neue Kante landet NICHT in der Geschoss-Checkliste — die beiden
    /// Wege teilen sich die Entity, aber nicht die Liste.
    @Test @MainActor func kanteTauchtNichtInGeschosslisteAuf() throws {
        let geschoss = Geschoss(context: ctx)
        geschoss.name = "EG"
        let a = macheAuftrag("Wasser erhitzen")
        let b = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(b, brauchtVorher: a, in: ctx)

        #expect(geschoss.voraussetzungenArray.isEmpty)
        #expect(b.voraussetzungenArray.first?.istKante == true)
        #expect(b.voraussetzungenArray.first?.art == .automatisch)
    }

    // MARK: - Löschregel

    /// Wird der Vorgänger gelöscht, verschwindet die Kante mit ihm. Sonst fiele
    /// sie auf `erfuellt` (Default NO) zurück und blockierte den Nachfolger für
    /// immer — ein Geist, den niemand mehr abhaken kann.
    @Test @MainActor func loeschenDesVorgaengersLoeschtDieKante() throws {
        let wasser = macheAuftrag("Wasser erhitzen")
        let nudeln = macheAuftrag("Nudeln kochen")
        try Kausalkette.verknuepfe(nudeln, brauchtVorher: wasser, in: ctx)
        try ctx.save()
        #expect(nudeln.istStartbar == false)

        ctx.delete(wasser)
        try ctx.save()

        #expect(nudeln.voraussetzungenArray.isEmpty)
        #expect(nudeln.istStartbar == true)
    }
}
