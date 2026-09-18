//
//  VermessungDXFLeserTests.swift
//  Erdaushub aus einer Vermessungs-DXF: Höhenpunkte lesen → Raster interpolieren →
//  Abtrag/Auftrag. Diese Tests halten das Parsen (CRLF/Layer/Ausreißer) und die Rechnung
//  an synthetischem Gelände fest.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct VermessungDXFLeserTests {

    /// Baut eine minimale DXF aus (layer, x, y, z)-Punkten (mit CRLF, wie echte DXF).
    private func dxf(_ pts: [(String, Double, Double, Double)]) -> Data {
        var s = ""
        for (layer, x, y, z) in pts {
            s += "  0\r\nPOINT\r\n  8\r\n\(layer)\r\n 10\r\n\(x)\r\n 20\r\n\(y)\r\n 30\r\n\(z)\r\n"
        }
        s += "  0\r\nEOF\r\n"
        return s.data(using: .isoLatin1)!
    }

    @Test func liestNurHoehenLayerUndFiltertAusreisser() {
        var pts: [(String, Double, Double, Double)] = []
        for x in stride(from: 0.0, through: 20, by: 10) {
            for y in stride(from: 0.0, through: 20, by: 10) {
                pts.append(("1_Punkt", x, y, 100.0))   // 9 flache Geländepunkte
            }
        }
        pts.append(("1_Punkt", 5, 5, 6.0))       // Ausreißer (Kanalsohle) → raus (weit vom Median)
        pts.append(("3_Kanal-Info_SW", 5, 5, 50)) // falscher Layer → ignoriert

        let p = VermessungDXFLeser.punkte(ausDXF: dxf(pts))
        #expect(p.count == 9)                      // nur die 9 Geländepunkte
        #expect(p.allSatisfy { $0.z == 100 })
    }

    @Test func flachesGelaendeMassenausgleichIstNull() {
        var pts: [(String, Double, Double, Double)] = []
        for x in stride(from: 0.0, through: 20, by: 5) {
            for y in stride(from: 0.0, through: 20, by: 5) {
                pts.append(("1_Punkt", x, y, 100.0))
            }
        }
        let e = try? #require(VermessungDXFLeser.lies(ausDXF: dxf(pts)))
        #expect(e != nil)
        // Flaches Gelände auf 100 m → jede Rasterzelle 100 m.
        #expect(abs(e!.modell.minHoehe - 100) < 1e-6)
        #expect(abs(e!.modell.maxHoehe - 100) < 1e-6)
        // Massenausgleich: Planum = 100, Abtrag = Auftrag = 0.
        let ma = ErdmassenRechner.massenausgleich(e!.modell)
        #expect(abs(ma.hoehe - 100) < 1e-6)
        #expect(ma.massen.abtragM3 < 1e-6)
    }

    @Test func aushubGegenPlanum() {
        // Flaches Gelände auf 100 m, Fläche 20×20 m (Raster 1 m → 400 Zellen à 1 m²).
        var pts: [(String, Double, Double, Double)] = []
        for x in stride(from: 0.0, through: 20, by: 5) {
            for y in stride(from: 0.0, through: 20, by: 5) {
                pts.append(("1_Punkt", x, y, 100.0))
            }
        }
        let e = try! #require(VermessungDXFLeser.lies(ausDXF: dxf(pts), zellM: 1.0))
        // Planum 98 m → Abtrag = 2 m × Fläche; kein Auftrag.
        let m = ErdmassenRechner.gegenEbene(e.modell, zielHoehe: 98)
        #expect(abs(m.abtragM3 - 2.0 * e.modell.flaeche) < 1e-6)
        #expect(m.auftragM3 < 1e-6)
        #expect(m.aushubM3 == m.abtragM3)   // Aushub = Abtrag (geht in die Maschinen-Kette)
    }
}
