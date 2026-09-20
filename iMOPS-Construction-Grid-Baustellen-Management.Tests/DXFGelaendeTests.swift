//
//  DXFGelaendeTests.swift
//  Die drei Stellen, an denen ein DXF-Gelände kippt: verschachtelte Blöcke,
//  der Maßstab und der Höhenanker. Dazu der Aushub selbst.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct DXFGelaendeTests {

    // MARK: - Hilfen zum Bauen von Test-DXF

    /// Baut DXF-Text Paar für Paar auf. Bewusst imperativ: lange „+"-Ketten aus
    /// Tupel-Arrays bringen den Swift-Typechecker zum Aufgeben.
    private final class DXFBauer {
        private var zeilen: [String] = []
        @discardableResult func p(_ code: String, _ wert: String) -> DXFBauer {
            zeilen.append(code); zeilen.append(wert); return self
        }
        @discardableResult func vertex(_ x: Double, _ y: Double, _ z: Double,
                                       layer: String = "0") -> DXFBauer {
            p("0", "VERTEX"); p("8", layer)
            p("10", String(x)); p("20", String(y)); p("30", String(z))
            return self
        }
        @discardableResult func insert(_ name: String, _ x: Double, _ y: Double, _ z: Double,
                                       drehung: Double? = nil) -> DXFBauer {
            p("0", "INSERT"); p("2", name)
            p("10", String(x)); p("20", String(y)); p("30", String(z))
            if let drehung { p("50", String(drehung)) }
            return self
        }
        @discardableResult func block(_ name: String, basisX: Double = 0, basisY: Double = 0,
                                      basisZ: Double = 0) -> DXFBauer {
            p("0", "BLOCK"); p("2", name)
            p("10", String(basisX)); p("20", String(basisY)); p("30", String(basisZ))
            return self
        }
        @discardableResult func abschnitt(_ name: String) -> DXFBauer {
            p("0", "SECTION"); p("2", name); return self
        }
        var text: String { zeilen.joined(separator: "\n") + "\n" }
    }

    // MARK: - Blockbaum

    @Test func insertDrehtUndVerschiebtDenPunkt() {
        // Punkt (1,2,3) in einem Block, eingefügt bei (10,20,1) mit 90° Drehung.
        // 90°: (1,2) → (−2,1); plus Einfügepunkt → (8,21); z 3+1 = 4.
        let b = DXFBauer()
        b.abschnitt("BLOCKS")
        b.block("GELAENDE")
        b.vertex(1, 2, 3)
        b.p("0", "ENDBLK"); b.p("0", "ENDSEC")
        b.abschnitt("ENTITIES")
        b.insert("GELAENDE", 10, 20, 1, drehung: 90)
        b.p("0", "ENDSEC"); b.p("0", "EOF")
        let text = b.text

        let modell = DXFGelaendeLeser.lies(dxf: text)
        #expect(modell.punkte.count == 1)
        let p = modell.punkte[0]
        #expect(abs(p.x - 8) < 1e-9)
        #expect(abs(p.y - 21) < 1e-9)
        #expect(abs(p.z - 4) < 1e-9)
        #expect(p.block == "GELAENDE")
    }

    @Test func verschachtelteBloeckeWerdenAufgeloest() {
        // AUSSEN enthält INSERT auf INNEN(+5/+5); INNEN hat den Punkt (1,1,1).
        // AUSSEN wird bei (100,100,0) eingefügt → Punkt bei (106,106,1).
        let b = DXFBauer()
        b.abschnitt("BLOCKS")
        b.block("INNEN")
        b.vertex(1, 1, 1)
        b.p("0", "ENDBLK")
        b.block("AUSSEN")
        b.insert("INNEN", 5, 5, 0)
        b.p("0", "ENDBLK"); b.p("0", "ENDSEC")
        b.abschnitt("ENTITIES")
        b.insert("AUSSEN", 100, 100, 0)
        b.p("0", "ENDSEC"); b.p("0", "EOF")
        let text = b.text

        let modell = DXFGelaendeLeser.lies(dxf: text)
        #expect(modell.punkte.count == 1)
        #expect(abs(modell.punkte[0].x - 106) < 1e-9)
        #expect(abs(modell.punkte[0].y - 106) < 1e-9)
        #expect(abs(modell.punkte[0].z - 1) < 1e-9)
    }

    @Test func blockbasisWirdAbgezogen() {
        // Basis (1,1,0), Punkt (1,1,0) → liegt genau auf der Basis → landet auf dem Einfügepunkt.
        let b = DXFBauer()
        b.abschnitt("BLOCKS")
        b.block("B", basisX: 1, basisY: 1)
        b.vertex(1, 1, 0)
        b.p("0", "ENDBLK"); b.p("0", "ENDSEC")
        b.abschnitt("ENTITIES")
        b.insert("B", 7, 9, 0)
        b.p("0", "ENDSEC"); b.p("0", "EOF")
        let text = b.text
        let m = DXFGelaendeLeser.lies(dxf: text)
        #expect(abs(m.punkte[0].x - 7) < 1e-9)
        #expect(abs(m.punkte[0].y - 9) < 1e-9)
    }

    @Test func polylineKopfLiefertKeinenGeisterpunkt() {
        // Eine POLYLINE mit Platzhalter-Koordinaten (0/0/0) und zwei echten VERTEX.
        let b = DXFBauer()
        b.abschnitt("ENTITIES")
        b.p("0", "POLYLINE"); b.p("8", "HL")
        b.p("10", "0.0"); b.p("20", "0.0"); b.p("30", "0.0"); b.p("70", "64")
        b.vertex(3, 4, 5, layer: "HL")
        b.vertex(6, 7, 8, layer: "HL")
        b.p("0", "SEQEND"); b.p("0", "ENDSEC"); b.p("0", "EOF")
        let text = b.text
        let m = DXFGelaendeLeser.lies(dxf: text)
        #expect(m.punkte.count == 2)
        #expect(!m.punkte.contains { $0.x == 0 && $0.y == 0 })
    }

    // MARK: - Maßstab

    @Test func winzigeSpannweiteSchlaegtZollAlsMeterVor() {
        // Ein „Grundstück" von 1,08 × 0,92 Einheiten — die SketchUp-Zollfalle.
        let punkte = [DXFPunkt(x: 0, y: 0, z: 0, layer: "0", block: "G"),
                      DXFPunkt(x: 1.08, y: 0.92, z: 0.197, layer: "0", block: "G")]
        let m = DXFRohmodell(punkte: punkte, proLayer: ["0": 2], proBlock: ["G": 2], abgebrochen: false)
        let (mass, text) = DXFMassstab.vorschlag(fuer: m)
        #expect(mass == .zollAlsMeter)
        #expect(abs(DXFMassstab.zollAlsMeter.faktor - 39.3700787) < 0.0001)
        #expect(text.contains("39"))
        // 0,197 Einheiten Höhenspanne sind in Wirklichkeit rund 7,8 m.
        #expect(abs(0.197 * mass.faktor - 7.756) < 0.01)
    }

    @Test func normaleSpannweiteBleibtMeter() {
        let punkte = [DXFPunkt(x: 0, y: 0, z: 0, layer: "0", block: "G"),
                      DXFPunkt(x: 54.7, y: 68.6, z: 8.2, layer: "0", block: "G")]
        let m = DXFRohmodell(punkte: punkte, proLayer: ["0": 2], proBlock: ["G": 2], abgebrochen: false)
        #expect(DXFMassstab.vorschlag(fuer: m).massstab == .meter)
    }

    // MARK: - Höhenanker

    @Test func hoehenversatzHebtDasModellAufMuNN() {
        // Echtfall-Kette: EG-Wandfuß Z 2,30 = OK Bodenplatte = RFB − 0,22 Bodenaufbau.
        let vorgabe = Aushubvorgabe(rohfussbodenMuNN: 196.10)
        #expect(abs(vorgabe.okBodenplatteMuNN - 195.88) < 1e-9)
        let versatz = Aushubrechner.hoehenversatz(modellZ: 2.30, entsprichtMuNN: vorgabe.okBodenplatteMuNN)
        #expect(abs(versatz - 193.58) < 1e-9)
        // Gegenprobe aus dem Werkplan: die Garagenplatte liegt im Modell auf Z 0,46.
        #expect(abs((0.46 + versatz) + 0.22 - 194.26) < 1e-9)
    }

    @Test func aushubsohleIstDieKetteUnterDemRohfussboden() {
        let v = Aushubvorgabe(rohfussbodenMuNN: 196.10, bodenaufbau: 0.22,
                              plattendicke: 0.16, polster: 0.65)
        #expect(abs(v.okBodenplatteMuNN - 195.88) < 1e-9)
        #expect(abs(v.ukBodenplatteMuNN - 195.72) < 1e-9)
        #expect(abs(v.sohleMuNN - 195.07) < 1e-9)
    }

    // MARK: - Rasterung

    @Test func punktwolkeWirdZumRaster() {
        // Ebenes Gelände auf 197,00 über 10 × 10 m, Punkte im 1-m-Netz.
        var punkte: [(x: Double, y: Double, z: Double)] = []
        for i in 0...10 { for j in 0...10 { punkte.append((Double(i), Double(j), 197.0)) } }
        let raster = Gelaendemodell.ausPunktwolke(punkte,
                                                  ausschnitt: Umriss(xMin: 0, xMax: 10, yMin: 0, yMax: 10),
                                                  zellgroesse: 0.5)
        #expect(raster != nil)
        #expect(raster?.zellenOhneTreffer == 0)
        #expect(abs((raster?.modell.flaeche ?? 0) - 100) < 0.01)
        #expect(abs((raster?.modell.mittlereHoehe ?? 0) - 197.0) < 1e-9)
    }

    @Test func zellenOhneGelaendepunktWerdenGemeldet() {
        // Nur eine Ecke ist mit Punkten belegt, gerastert wird ein viel größerer Bereich.
        let punkte: [(x: Double, y: Double, z: Double)] = [(0, 0, 100), (0.5, 0.5, 100), (1, 1, 100)]
        let raster = Gelaendemodell.ausPunktwolke(punkte,
                                                  ausschnitt: Umriss(xMin: 0, xMax: 40, yMin: 0, yMax: 40),
                                                  zellgroesse: 1.0)
        #expect(raster != nil)
        #expect((raster?.zellenOhneTreffer ?? 0) > 0)
        #expect(raster?.hinweis != nil)
        #expect((raster?.abdeckung ?? 1) < 0.9)
    }

    // MARK: - Aushub

    @Test func ebenesGelaendeGibtFlaecheMalTiefe() {
        // Gelände waagerecht auf 197,00; RFB 196,10 → Sohle 195,07 → 1,93 m Abtrag.
        // Umriss 8 × 9,50 plus 0,50 m Arbeitsraum = 9,00 × 10,50 = 94,5 m².
        var punkte: [(x: Double, y: Double, z: Double)] = []
        for i in -2...14 { for j in -2...14 { punkte.append((Double(i), Double(j), 197.0)) } }
        let vorgabe = Aushubvorgabe(rohfussbodenMuNN: 196.10)
        let erg = Aushubrechner.rechne(gelaende: punkte,
                                       umriss: Umriss(xMin: 0, xMax: 8, yMin: 0, yMax: 9.5),
                                       vorgabe: vorgabe, zellgroesse: 0.25)
        #expect(erg != nil)
        guard let e = erg else { return }
        #expect(abs(e.sohleMuNN - 195.07) < 1e-9)
        #expect(abs(e.flaecheM2 - 94.5) < 0.01)
        #expect(abs(e.abtragM3 - 94.5 * 1.93) < 0.5)      // 182,4 m³
        #expect(e.auftragM3 == 0)
        #expect(abs(e.mittlereTiefe - 1.93) < 0.01)
    }

    @Test func gelaendeUnterDerSohleWirdAuftrag() {
        var punkte: [(x: Double, y: Double, z: Double)] = []
        for i in -2...12 { for j in -2...12 { punkte.append((Double(i), Double(j), 194.0)) } }
        let erg = Aushubrechner.rechne(gelaende: punkte,
                                       umriss: Umriss(xMin: 0, xMax: 8, yMin: 0, yMax: 8),
                                       vorgabe: Aushubvorgabe(rohfussbodenMuNN: 196.10),
                                       zellgroesse: 0.5)
        #expect(erg?.abtragM3 == 0)
        #expect((erg?.auftragM3 ?? 0) > 0)
    }

    @Test func hangGibtAbtragUndKeinenAuftrag() {
        // Gelände fällt von 197,5 auf 195,5 über 10 m — Hanglage wie im Echtfall.
        var punkte: [(x: Double, y: Double, z: Double)] = []
        for i in -2...14 {
            for j in -2...14 {
                punkte.append((Double(i), Double(j), 197.5 - 0.2 * Double(j)))
            }
        }
        let erg = Aushubrechner.rechne(gelaende: punkte,
                                       umriss: Umriss(xMin: 0, xMax: 8, yMin: 0, yMax: 9.5),
                                       vorgabe: Aushubvorgabe(rohfussbodenMuNN: 196.10),
                                       zellgroesse: 0.25)
        guard let e = erg else { #expect(Bool(false), "kein Ergebnis"); return }
        #expect(e.abtragM3 > 0)
        #expect(e.gelaendeMax > e.gelaendeMin)
        #expect(e.rechenweg.contains("Aushubsohle") || e.rechenweg.contains("müNN"))
    }

    // MARK: - Gebäudeumriss aus der Zeichnung MIT Haus

    @Test func umrissKommtAusDenWandLayern() {
        let b = DXFBauer()
        b.abschnitt("ENTITIES")
        b.vertex(3.5, 7.0, 2.3, layer: "EG_AW_Wände")
        b.vertex(11.5, 7.0, 2.3, layer: "EG_AW_Wände")
        b.vertex(11.5, 16.5, 5.05, layer: "EG_AW_Wände")
        b.vertex(3.5, 16.5, 5.05, layer: "EG_AW_Wände")
        b.vertex(99.0, 99.0, 0.0, layer: "Bäume")     // darf den Umriss nicht aufblähen
        b.p("0", "ENDSEC"); b.p("0", "EOF")
        let text = b.text
        let m = DXFGelaendeLeser.lies(dxf: text)
        let u = DXFGelaendeLeser.gebaeudeUmriss(m)
        #expect(u != nil)
        #expect(abs((u?.breite ?? 0) - 8.0) < 1e-9)
        #expect(abs((u?.tiefe ?? 0) - 9.5) < 1e-9)
        #expect(abs((u?.flaeche ?? 0) - 76.0) < 1e-6)
    }

    @Test func umrissMitArbeitsraumWirdGroesser() {
        let u = Umriss(xMin: 0, xMax: 8, yMin: 0, yMax: 9.5).erweitert(um: 0.5)
        #expect(abs(u.breite - 9.0) < 1e-9)
        #expect(abs(u.tiefe - 10.5) < 1e-9)
        #expect(abs(u.flaeche - 94.5) < 1e-9)
    }
}
