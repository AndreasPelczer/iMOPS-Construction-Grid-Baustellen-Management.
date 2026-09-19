//
//  PreisAnhaengeTests.swift
//  Der Beweis: der Matcher ordnet die richtige Stammdaten-Material der Position zu
//  (Beton-Position → Beton, Bewehrung → Betonstahl, Wand → Ytong) — und das Anhängen
//  ist idempotent (kein Doppel). So springt der EP von "nur Lohn" auf "Lohn + Material".
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct PreisAnhaengeTests {

    private let controller = PersistenceController(inMemory: true)
    private let service = PreisAnhaengeService.shared

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func material(_ name: String, _ einheit: String, _ preis: Double) -> KalkMaterial {
        let m = KalkMaterial(context: ctx)
        m.id = UUID(); m.name = name; m.einheit = einheit; m.preisProEinheit = preis
        return m
    }

    @MainActor
    private func position(_ bez: String, _ einheit: String) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.bezeichnung = bez; p.einheit = einheit; p.menge = 10
        return p
    }

    @MainActor
    private func stammMaterialien() -> [KalkMaterial] {
        [material("Beton C25/30", "m3", 130),
         material("Betonstahl B500A", "kg", 1.20),
         material("Ytong 24 PPW2/0,35", "m2", 34)]
    }

    // MARK: - Der Matcher trifft das Richtige

    @Test @MainActor
    func betonPositionTrifftBeton() {
        let m = stammMaterialien()
        let pos = position("Beton Bodenplatte C25/30 d=16", "m3")
        let v = service.besterVorschlag(fuer: pos, aus: m)
        #expect(v?.material.name == "Beton C25/30")
        #expect(v?.einheitPasst == true)   // m3 == m3
    }

    @Test @MainActor
    func bewehrungTrifftBetonstahlNichtBeton() {
        let m = stammMaterialien()
        let pos = position("Betonstahl B500A Stabstahl", "kg")
        let v = service.besterVorschlag(fuer: pos, aus: m)
        #expect(v?.material.name == "Betonstahl B500A")   // NICHT "Beton C25/30"
    }

    @Test @MainActor
    func ytongWandTrifftYtongTrotzBindestrichSlash() {
        let m = stammMaterialien()
        // Position schreibt "PPW2-0,35" (Bindestrich), Stammdaten "PPW2/0,35" (Slash).
        let pos = position("Mauerwerk Aussenwand Ytong 24 PPW2-0,35", "m2")
        let v = service.besterVorschlag(fuer: pos, aus: m)
        #expect(v?.material.name == "Ytong 24 PPW2/0,35")
    }

    @Test @MainActor
    func keinFalscherTrefferBeiFremderPosition() {
        let m = stammMaterialien()
        let pos = position("Bodenaushub abfahren und entsorgen", "m3")
        // Deponie ist nicht in den Stammdaten → kein sicherer Treffer, lieber nichts.
        #expect(service.besterVorschlag(fuer: pos, aus: m) == nil)
    }

    // MARK: - Anhängen: EP steigt, idempotent

    @Test @MainActor
    func haengtMaterialAnUndVerdoppeltNicht() throws {
        let m = stammMaterialien()
        let pos = position("Beton Bodenplatte C25/30 d=16", "m3")
        let beton = try #require(service.besterVorschlag(fuer: pos, aus: m)).material

        #expect(service.haengeAn(material: beton, an: pos, in: ctx) == true)
        #expect(pos.materialArray.count == 1)
        #expect(abs(pos.materialArray.first!.einzelpreis - 130) < 0.001)
        #expect(pos.materialArray.first!.quelle == "eigen")

        // Zweiter Aufruf hängt NICHT nochmal an.
        #expect(service.haengeAn(material: beton, an: pos, in: ctx) == false)
        #expect(pos.materialArray.count == 1)
    }
}
