//
//  PlanMassTests.swift
//  „Plan abgreifen": aus Bildpunkten + Maßstab Länge und Fläche in Metern.
//

import Testing
import Foundation
import CoreGraphics
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct PlanMassTests {

    @Test func distanzUndFlaeche() {
        #expect(PlanMass.distanz(CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)) == 5)
        // 100×100-Quadrat → 10000 (Bild-Einheiten²).
        let q = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
                 CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]
        #expect(PlanMass.flaeche(q) == 10000)
        #expect(PlanMass.umfang(q) == 400)
        let lb = PlanMass.boundingLB(q)
        #expect(lb.l == 100 && lb.b == 100)
    }

    @Test func maßstabUndMasseInMetern() {
        // Kalibrierung: 100 px entsprechen 10 m → 0,1 m/px.
        let mpe = try? #require(PlanMass.meterProEinheit(kalibA: CGPoint(x: 0, y: 0),
                                                         kalibB: CGPoint(x: 100, y: 0), echteMeter: 10))
        #expect(mpe != nil)
        #expect(abs((mpe ?? 0) - 0.1) < 1e-9)

        // Ein 100×100-px-Haus → 10×10 m = 100 m².
        let haus = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0),
                    CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]
        let m = PlanMass.masse(polygon: haus, meterProEinheit: mpe!)
        #expect(abs(m.flaecheM2 - 100) < 1e-6)
        #expect(abs(m.laengeM - 10) < 1e-6)
        #expect(abs(m.breiteM - 10) < 1e-6)
        #expect(abs(m.umfangM - 40) < 1e-6)
    }

    @Test func fehlendeKalibrierungGibtNil() {
        // Punkte fallen zusammen → kein Maßstab.
        #expect(PlanMass.meterProEinheit(kalibA: .zero, kalibB: .zero, echteMeter: 10) == nil)
        #expect(PlanMass.meterProEinheit(kalibA: .zero, kalibB: CGPoint(x: 100, y: 0), echteMeter: 0) == nil)
    }
}
