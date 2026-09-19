//
//  BewehrungsGewichteTests.swift
//  Beweis: die Stabstahl-Gewichte kommen aus der Physik (DIN 488), die Matten aus
//  festen Standardwerten — keine geratene Zahl.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BewehrungsGewichteTests {

    // Toleranz: die DIN-Tabellenwerte sind auf 3 Nachkommastellen gerundet.
    private let cent = 0.002

    @Test func stabstahlPhysikStimmtMitDINTabelle() {
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 8)  - 0.395) < cent)
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 10) - 0.617) < cent)
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 12) - 0.888) < cent)
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 16) - 1.578) < cent)
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 20) - 2.466) < cent)
        #expect(abs(BewehrungsGewichte.stabstahlKgProMeter(durchmesserMM: 40) - 9.865) < cent)
    }

    @Test func stabstahlGesamtgewicht() {
        // 25 Stäbe Ø12, je 6 m → 25 × 6 × 0,888 = 133,2 kg
        let kg = BewehrungsGewichte.stabstahlGewicht(durchmesserMM: 12, laengeM: 6, anzahl: 25)
        #expect(abs(kg - 133.2) < 0.2)
    }

    @Test func mattenNachTypUndFlaeche() {
        // Q188A = 3,02 kg/m²; „A" und Leerzeichen egal
        #expect(abs((BewehrungsGewichte.mattenGewicht(typ: "Q188A", flaecheM2: 100) ?? 0) - 302) < 0.5)
        #expect(abs((BewehrungsGewichte.mattenGewicht(typ: "q 188",  flaecheM2: 100) ?? 0) - 302) < 0.5)
        #expect(BewehrungsGewichte.mattenGewicht(typ: "gibtsnicht", flaecheM2: 100) == nil)
    }
}
