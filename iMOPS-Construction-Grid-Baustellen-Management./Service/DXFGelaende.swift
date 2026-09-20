//
//  DXFGelaende.swift
//  Bogen 1, Stufe 2 (Geländebrücke): aus zwei DXF den Aushub rechnen.
//
//  Der Weg, den Andreas beschreibt: der Architekt liefert einen Plan OHNE Haus (das
//  Geländemodell des Vermessers) und danach die Grundstückszeichnung MIT Haus. Beide
//  liegen im selben Koordinatensystem. Damit ist der Aushub keine Schätzung mehr:
//
//      Gelände (Punktwolke)  →  Höhenraster  →  ErdmassenRechner.gegenEbene(Sohle)
//      Haus (Umriss)         →  Ausschnitt + Arbeitsraum
//      Rohfußboden müNN      →  Aushubsohle
//
//  Drei Dinge, an denen es in der Praxis hakt, und wie sie hier gelöst sind:
//
//  1. VERSCHACHTELTE BLÖCKE. SketchUp-DXF legen ALLES in Blöcke; der ENTITIES-Abschnitt
//     enthält nur die obersten INSERTs. Deshalb wird der Blockbaum rekursiv aufgelöst:
//     q = R(rot) · S(scale) · (p − Blockbasis) + Einfügepunkt, von außen nach innen verkettet.
//  2. MASSSTAB. SketchUp-Exporte kommen oft als „Zoll-als-Meter" (1 Einheit = 39,37 m) —
//     der Header ($INSUNITS) lügt dabei. Erkannt wird das an der Spannweite: ein Grundstück
//     ist keine 1,08 Einheiten breit. Der Faktor wird VORGESCHLAGEN, nie still angewendet.
//  3. HÖHENANKER. Ein SketchUp-Gelände hat meist eine eigene Null. Über ein bekanntes
//     Bauteil (OK Bodenplatte = Rohfußboden − Bodenaufbau) wird der Versatz gesetzt;
//     der Leser zeigt danach die Geländespanne in müNN, damit man gegen bekannte Werte
//     (Straßenhöhe, Nachbarhöhe) gegenprüfen kann.
//
//  EHRLICH (Tao): das Ergebnis ist ein geometrisches Volumen im gewachsenen Zustand —
//  ohne Auflockerung, ohne Böschungsausrundung, kein Vermesser-Aufmaß. Zellen ohne
//  Geländepunkt werden GEZÄHLT und gemeldet, nicht heimlich interpoliert.
//

import Foundation

// MARK: - Punkte und Umriss

/// Ein Punkt aus der DXF, Blöcke bereits aufgelöst (Weltkoordinaten in Modell-Einheiten).
struct DXFPunkt {
    let x: Double
    let y: Double
    let z: Double
    let layer: String
    /// Name des innersten Blocks ("" = direkt im Modellbereich gezeichnet).
    let block: String
}

/// Rechteckiger Ausschnitt in der Ebene (Bounding Box), z.B. der Hausumriss.
struct Umriss: Equatable {
    var xMin: Double
    var xMax: Double
    var yMin: Double
    var yMax: Double

    var breite: Double { max(0, xMax - xMin) }
    var tiefe: Double { max(0, yMax - yMin) }
    var flaeche: Double { breite * tiefe }
    var istLeer: Bool { breite <= 0 || tiefe <= 0 }

    /// Umriss allseitig erweitern — der Arbeitsraum nach DIN 4124.
    func erweitert(um d: Double) -> Umriss {
        Umriss(xMin: xMin - d, xMax: xMax + d, yMin: yMin - d, yMax: yMax + d)
    }

    /// Mit einem Faktor skalieren (Maßstabskorrektur).
    func skaliert(_ f: Double) -> Umriss {
        Umriss(xMin: xMin * f, xMax: xMax * f, yMin: yMin * f, yMax: yMax * f)
    }

    static func umschliessend(_ punkte: [DXFPunkt]) -> Umriss? {
        guard let first = punkte.first else { return nil }
        var u = Umriss(xMin: first.x, xMax: first.x, yMin: first.y, yMax: first.y)
        for p in punkte {
            u.xMin = min(u.xMin, p.x); u.xMax = max(u.xMax, p.x)
            u.yMin = min(u.yMin, p.y); u.yMax = max(u.yMax, p.y)
        }
        return u
    }
}

// MARK: - Affine Abbildung (Blocktransformation)

/// Verschiebung + Drehung um Z + Skalierung. XY als 2×2-Matrix, Z getrennt
/// (DXF-INSERTs drehen nur um die Z-Achse — mehr braucht ein Geländemodell nicht).
struct DXFAbbildung {
    var a = 1.0, b = 0.0, c = 0.0, d = 1.0    // 2×2 für XY
    var tx = 0.0, ty = 0.0
    var sz = 1.0, tz = 0.0

    static let identitaet = DXFAbbildung()

    func anwenden(_ x: Double, _ y: Double, _ z: Double) -> (x: Double, y: Double, z: Double) {
        (a * x + b * y + tx, c * x + d * y + ty, sz * z + tz)
    }

    /// Diese Abbildung außen, `innen` innen: erst innen, dann selbst.
    func verkettet(mit innen: DXFAbbildung) -> DXFAbbildung {
        var r = DXFAbbildung()
        r.a = a * innen.a + b * innen.c
        r.b = a * innen.b + b * innen.d
        r.c = c * innen.a + d * innen.c
        r.d = c * innen.b + d * innen.d
        r.tx = a * innen.tx + b * innen.ty + tx
        r.ty = c * innen.tx + d * innen.ty + ty
        r.sz = sz * innen.sz
        r.tz = sz * innen.tz + tz
        return r
    }

    /// Die Abbildung eines INSERT: q = R(rot)·S(scale)·(p − Basis) + Einfügepunkt.
    static func fuerInsert(einfuegen: (x: Double, y: Double, z: Double),
                           basis: (x: Double, y: Double, z: Double),
                           skalierung: (x: Double, y: Double, z: Double),
                           drehungGrad: Double) -> DXFAbbildung {
        let w = drehungGrad * .pi / 180
        let co = cos(w), si = sin(w)
        var t = DXFAbbildung()
        t.a = co * skalierung.x
        t.b = -si * skalierung.y
        t.c = si * skalierung.x
        t.d = co * skalierung.y
        t.sz = skalierung.z
        t.tx = einfuegen.x - (t.a * basis.x + t.b * basis.y)
        t.ty = einfuegen.y - (t.c * basis.x + t.d * basis.y)
        t.tz = einfuegen.z - t.sz * basis.z
        return t
    }
}

// MARK: - Rohmodell

/// Das gelesene DXF in Modell-Einheiten — noch ohne Maßstab und ohne Höhenanker.
struct DXFRohmodell {
    let punkte: [DXFPunkt]
    /// Punktzahl je Layer (für die Auswahl „welcher Layer ist das Gelände / das Haus?").
    let proLayer: [String: Int]
    /// Punktzahl je Blockname.
    let proBlock: [String: Int]
    /// Wie tief der Blockbaum aufgelöst wurde (Warnung bei Abbruch).
    let abgebrochen: Bool

    var istLeer: Bool { punkte.isEmpty }
    var umriss: Umriss? { Umriss.umschliessend(punkte) }
    var zMin: Double { punkte.map(\.z).min() ?? 0 }
    var zMax: Double { punkte.map(\.z).max() ?? 0 }
    var zSpanne: Double { zMax - zMin }

    /// Punkte eines Layers oder Blocks, dessen Name einen der Begriffe enthält (klein geschrieben).
    func punkte(mitBegriffen begriffe: [String]) -> [DXFPunkt] {
        guard !begriffe.isEmpty else { return punkte }
        return punkte.filter { p in
            let l = p.layer.lowercased(), b = p.block.lowercased()
            return begriffe.contains { l.contains($0) || b.contains($0) }
        }
    }

    /// Der größte zusammenhängende Träger von Höheninformation — meist das Geländemesh.
    /// Genommen wird der Block mit den meisten Punkten UND einer Höhenspanne > 0,5 Einheiten·f.
    func groesstesHoehenmodell(mindestpunkte: Int = 200) -> (block: String, punkte: [DXFPunkt])? {
        var beste: (String, [DXFPunkt])?
        for (name, anzahl) in proBlock where anzahl >= mindestpunkte {
            let ps = punkte.filter { $0.block == name }
            guard let lo = ps.map(\.z).min(), let hi = ps.map(\.z).max(), hi > lo else { continue }
            if beste == nil || ps.count > beste!.1.count { beste = (name, ps) }
        }
        return beste.map { (block: $0.0, punkte: $0.1) }
    }
}

// MARK: - Maßstab

/// Was für eine Einheit steckt im DXF? Der Vorschlag ist eine Vermutung aus der
/// Spannweite — der Mensch bestätigt ihn, der Mops rechnet nicht heimlich um.
enum DXFMassstab: Hashable {
    case meter                 // 1 Einheit = 1 m
    case zollAlsMeter          // 1 Einheit = 39,3701 m (SketchUp-Zollfalle)
    case eigen(Double)

    var faktor: Double {
        switch self {
        case .meter: return 1
        case .zollAlsMeter: return 1 / 0.0254      // 39,3700787…
        case .eigen(let f): return f
        }
    }

    var name: String {
        switch self {
        case .meter: return "Meter (1:1)"
        case .zollAlsMeter: return "Zoll-als-Meter (× 39,37)"
        case .eigen(let f): return String(format: "eigener Faktor × %.4f", f)
        }
    }

    /// Unterhalb dieser Spannweite (in Modell-Einheiten) ist ein Grundstück unplausibel klein.
    static let verdachtsschwelle = 5.0

    /// Vorschlag aus der Spannweite des Modells.
    static func vorschlag(fuer modell: DXFRohmodell) -> (massstab: DXFMassstab, begruendung: String) {
        guard let u = modell.umriss else { return (.meter, "Keine Punkte gefunden.") }
        let spanne = max(u.breite, u.tiefe)
        if spanne > 0, spanne < verdachtsschwelle {
            let f = DXFMassstab.zollAlsMeter.faktor
            return (.zollAlsMeter, String(format:
                "Das Modell spannt nur %.2f × %.2f Einheiten — für ein Grundstück zu klein. "
                + "Typische SketchUp-Zollfalle: mit × %.2f wären es %.1f × %.1f m.",
                u.breite, u.tiefe, f, u.breite * f, u.tiefe * f))
        }
        return (.meter, String(format:
            "Spannweite %.1f × %.1f Einheiten — plausibel als Meter, kein Umrechnen nötig.",
            u.breite, u.tiefe))
    }
}

// MARK: - Leser

enum DXFGelaendeLeser {

    /// Schutz vor Endlosschleifen bei sich selbst enthaltenden Blöcken.
    static let maxTiefe = 12

    struct RohEintrag {
        var typ: String
        var paare: [(code: String, wert: String)] = []

        func erster(_ code: String) -> String? { paare.first { $0.code == code }?.wert }
        func zahl(_ code: String) -> Double? { erster(code).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) } }
        func alle(_ code: String) -> [Double] {
            paare.filter { $0.code == code }.compactMap { Double($0.wert.replacingOccurrences(of: ",", with: ".")) }
        }
        var layer: String { erster("8").flatMap { $0.isEmpty ? nil : $0 } ?? "0" }
    }

    private struct Block {
        var basis: (x: Double, y: Double, z: Double) = (0, 0, 0)
        var eintraege: [RohEintrag] = []
        var inserts: [RohEintrag] = []
    }

    /// DXF-Text einlesen und den Blockbaum auflösen.
    static func lies(dxf text: String) -> DXFRohmodell {
        var bloecke: [String: Block] = [:]
        var topEintraege: [RohEintrag] = []
        var topInserts: [RohEintrag] = []

        var abschnitt = ""
        var aktBlock: String?
        var akt: RohEintrag?
        var wartetAufAbschnittsname = false

        func ablegen(_ e: RohEintrag) {
            switch e.typ {
            case "BLOCK":
                let name = e.erster("2") ?? ""
                guard !name.isEmpty else { return }
                var b = bloecke[name] ?? Block()
                b.basis = (e.zahl("10") ?? 0, e.zahl("20") ?? 0, e.zahl("30") ?? 0)
                bloecke[name] = b
                aktBlock = name
            case "ENDBLK":
                aktBlock = nil
            case "INSERT":
                if abschnitt == "BLOCKS", let bn = aktBlock {
                    bloecke[bn, default: Block()].inserts.append(e)
                } else if abschnitt == "ENTITIES" {
                    topInserts.append(e)
                }
            // POLYLINE selbst trägt keine Geometrie (ihr Code 10/20/30 ist ein Platzhalter) —
            // die Punkte stehen in den folgenden VERTEX-Einträgen. Sonst kämen Geisterpunkte
            // im Blockursprung dazu.
            case "VERTEX", "POINT", "3DFACE", "LINE", "LWPOLYLINE":
                if abschnitt == "BLOCKS", let bn = aktBlock {
                    bloecke[bn, default: Block()].eintraege.append(e)
                } else if abschnitt == "ENTITIES" {
                    topEintraege.append(e)
                }
            default:
                break
            }
        }

        // DXF ist paarweise: Zeile 1 = Gruppencode, Zeile 2 = Wert. Robust gegen CRLF
        // und rechtsbündige Codes ("  8", " 10").
        var code: String?
        text.enumerateLines { zeile, _ in
            let s = zeile.trimmingCharacters(in: .whitespaces)
            guard let c = code else { code = s; return }
            code = nil
            let wert = s

            if c == "0" {
                if let e = akt { ablegen(e) }
                akt = RohEintrag(typ: wert)
                if wert == "SECTION" { wartetAufAbschnittsname = true; abschnitt = "" }
                if wert == "ENDSEC" { abschnitt = "" }
                return
            }
            if wartetAufAbschnittsname, c == "2" {
                abschnitt = wert; wartetAufAbschnittsname = false
                return
            }
            akt?.paare.append((c, wert))
        }
        if let e = akt { ablegen(e) }

        // Auflösen
        var punkte: [DXFPunkt] = []
        var abgebrochen = false

        func punkteAus(_ e: RohEintrag, _ t: DXFAbbildung, block: String) {
            func add(_ x: Double?, _ y: Double?, _ z: Double?) {
                guard let x, let y else { return }
                let p = t.anwenden(x, y, z ?? 0)
                punkte.append(DXFPunkt(x: p.x, y: p.y, z: p.z, layer: e.layer, block: block))
            }
            switch e.typ {
            case "VERTEX", "POINT":
                add(e.zahl("10"), e.zahl("20"), e.zahl("30"))
            case "LINE":
                add(e.zahl("10"), e.zahl("20"), e.zahl("30"))
                add(e.zahl("11"), e.zahl("21"), e.zahl("31"))
            case "3DFACE":
                for i in 0..<4 {
                    add(e.zahl("1\(i)"), e.zahl("2\(i)"), e.zahl("3\(i)"))
                }
            case "LWPOLYLINE":
                let xs = e.alle("10"), ys = e.alle("20")
                let hoehe = e.zahl("38") ?? 0
                for (x, y) in zip(xs, ys) { add(x, y, hoehe) }
            default:
                break
            }
        }

        func gehe(_ ins: RohEintrag, _ aussen: DXFAbbildung, _ tiefe: Int) {
            guard tiefe <= maxTiefe else { abgebrochen = true; return }
            guard let name = ins.erster("2"), let b = bloecke[name] else { return }
            let eigen = DXFAbbildung.fuerInsert(
                einfuegen: (ins.zahl("10") ?? 0, ins.zahl("20") ?? 0, ins.zahl("30") ?? 0),
                basis: b.basis,
                skalierung: (ins.zahl("41") ?? 1, ins.zahl("42") ?? 1, ins.zahl("43") ?? 1),
                drehungGrad: ins.zahl("50") ?? 0)
            let t = aussen.verkettet(mit: eigen)
            for e in b.eintraege { punkteAus(e, t, block: name) }
            for kind in b.inserts { gehe(kind, t, tiefe + 1) }
        }

        for e in topEintraege { punkteAus(e, .identitaet, block: "") }
        for ins in topInserts { gehe(ins, .identitaet, 0) }

        var proLayer: [String: Int] = [:]
        var proBlock: [String: Int] = [:]
        for p in punkte {
            proLayer[p.layer, default: 0] += 1
            proBlock[p.block, default: 0] += 1
        }
        return DXFRohmodell(punkte: punkte, proLayer: proLayer, proBlock: proBlock,
                            abgebrochen: abgebrochen)
    }

    /// Layer-/Blocknamen, die typischerweise ein Gebäude tragen (Wände).
    static let gebaeudeBegriffe = ["_aw_", "aw_", "aussenwand", "außenwand", "wand", "wall", "mauer"]

    /// Umriss des Gebäudes aus einer Zeichnung MIT Haus: Bounding Box aller Wandpunkte.
    static func gebaeudeUmriss(_ modell: DXFRohmodell) -> Umriss? {
        let ps = modell.punkte(mitBegriffen: gebaeudeBegriffe)
        guard ps.count >= 4 else { return nil }
        return Umriss.umschliessend(ps)
    }
}

// MARK: - Punktwolke → Höhenraster

/// Ergebnis der Rasterung — inklusive der ehrlichen Zahl der Zellen ohne Geländepunkt.
struct PunktRaster {
    let modell: Gelaendemodell
    let zellenGesamt: Int
    let zellenOhneTreffer: Int
    let hinweis: String?

    var abdeckung: Double {
        zellenGesamt == 0 ? 0 : Double(zellenGesamt - zellenOhneTreffer) / Double(zellenGesamt)
    }
}

extension Gelaendemodell {

    /// Baut ein Höhenraster aus einer unregelmäßigen Punktwolke (DXF-Geländemesh).
    /// Je Rasterzelle wird der nächstgelegene Geländepunkt genommen (die Meshpunkte
    /// liegen dichter als das Raster — für ein TIN ist das genau genug).
    ///
    /// - Parameters:
    ///   - punkte: Geländepunkte in METERN (Maßstab bereits angewendet).
    ///   - ausschnitt: der zu rasternde Bereich (Hausumriss + Arbeitsraum), in Metern.
    ///   - zellgroesse: Kantenlänge einer Rasterzelle in m (Vorgabe 0,25 m).
    ///   - hoehenversatz: wird auf jede Höhe addiert (Anker lokal → müNN).
    ///   - maxRinge: wie weit um die Zelle herum nach einem Punkt gesucht wird.
    static func ausPunktwolke(_ punkte: [(x: Double, y: Double, z: Double)],
                              ausschnitt: Umriss,
                              zellgroesse: Double = 0.25,
                              hoehenversatz: Double = 0,
                              maxRinge: Int = 4) -> PunktRaster? {
        guard zellgroesse > 0, !ausschnitt.istLeer, !punkte.isEmpty else { return nil }

        // Räumlicher Eimer-Index, Eimerkante mindestens 1 m (sonst zu viele leere Eimer).
        let eimer = max(1.0, zellgroesse * 4)
        var index: [Int64: [(x: Double, y: Double, z: Double)]] = [:]
        func schluessel(_ ix: Int, _ iy: Int) -> Int64 { Int64(ix) &* 1_000_003 &+ Int64(iy) }
        for p in punkte {
            let ix = Int(floor(p.x / eimer)), iy = Int(floor(p.y / eimer))
            index[schluessel(ix, iy), default: []].append(p)
        }

        let spalten = max(1, Int((ausschnitt.breite / zellgroesse).rounded()))
        let zeilen = max(1, Int((ausschnitt.tiefe / zellgroesse).rounded()))
        var hoehen: [[Double]] = []
        var ohneTreffer = 0
        var letzteGueltige = 0.0
        var gefundenIrgendwas = false

        // Y absteigend, damit „Norden oben" wie beim DGM1-Leser gilt.
        for zeile in 0..<zeilen {
            var reihe: [Double] = []
            let y = ausschnitt.yMax - (Double(zeile) + 0.5) * zellgroesse
            for spalte in 0..<spalten {
                let x = ausschnitt.xMin + (Double(spalte) + 0.5) * zellgroesse
                let ix = Int(floor(x / eimer)), iy = Int(floor(y / eimer))
                var beste: Double?
                var besteDistanz = Double.greatestFiniteMagnitude
                var ring = 0
                while ring <= maxRinge {
                    for dx in -ring...ring {
                        for dy in -ring...ring where abs(dx) == ring || abs(dy) == ring || ring == 0 {
                            for p in index[schluessel(ix + dx, iy + dy)] ?? [] {
                                let dist = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y)
                                if dist < besteDistanz { besteDistanz = dist; beste = p.z }
                            }
                        }
                    }
                    if beste != nil { break }
                    ring += 1
                }
                if let b = beste {
                    letzteGueltige = b + hoehenversatz
                    gefundenIrgendwas = true
                    reihe.append(letzteGueltige)
                } else {
                    ohneTreffer += 1
                    reihe.append(letzteGueltige)   // Platzhalter, wird unten ehrlich gemeldet
                }
            }
            hoehen.append(reihe)
        }
        guard gefundenIrgendwas, let modell = Gelaendemodell(hoehen: hoehen, dx: zellgroesse, dy: zellgroesse)
        else { return nil }

        let gesamt = zeilen * spalten
        var hinweis: String?
        if ohneTreffer > 0 {
            let anteil = Double(ohneTreffer) / Double(gesamt) * 100
            hinweis = String(format:
                "%d von %d Rasterzellen (%.0f %%) liegen außerhalb der Geländepunkte — "
                + "dort wurde der zuletzt bekannte Wert eingesetzt. Bei mehr als 10 %% "
                + "deckt das Geländemodell den Bereich nicht ab.", ohneTreffer, gesamt, anteil)
        }
        return PunktRaster(modell: modell, zellenGesamt: gesamt,
                           zellenOhneTreffer: ohneTreffer, hinweis: hinweis)
    }
}

// MARK: - Aushub

/// Was zwischen Rohfußboden und Aushubsohle liegt — die Kette, die jeder Polier kennt.
struct Aushubvorgabe {
    /// Rohfußboden EG in müNN (aus dem Werkplan).
    var rohfussbodenMuNN: Double
    /// Bodenaufbau über der Bodenplatte (Estrich + Dämmung), Vorgabe 0,22 m.
    var bodenaufbau: Double = 0.22
    /// Dicke der Bodenplatte, Vorgabe 0,16 m.
    var plattendicke: Double = 0.16
    /// Stabilisierungspolster / Frostschutz unter der Platte (aus dem Bodengutachten).
    var polster: Double = 0.65
    /// Arbeitsraum allseitig um den Baukörper (DIN 4124), Vorgabe 0,50 m.
    var arbeitsraum: Double = 0.50

    var okBodenplatteMuNN: Double { rohfussbodenMuNN - bodenaufbau }
    var ukBodenplatteMuNN: Double { okBodenplatteMuNN - plattendicke }
    var sohleMuNN: Double { ukBodenplatteMuNN - polster }
}

struct Aushubergebnis {
    let sohleMuNN: Double
    let ausschnitt: Umriss
    let flaecheM2: Double
    let gelaendeMin: Double
    let gelaendeMax: Double
    let gelaendeMittel: Double
    let abtragM3: Double
    let auftragM3: Double
    let zellenOhneTreffer: Int
    let rasterHinweis: String?

    var mittlereTiefe: Double { flaecheM2 > 0 ? abtragM3 / flaecheM2 : 0 }

    /// Der Rechenweg in einem Satz — kommt so in den Langtext der LV-Position.
    var rechenweg: String {
        String(format: "Aus Geländemodell gerechnet: %.1f m² (Umriss %.2f × %.2f m inkl. Arbeitsraum) "
               + "gegen Aushubsohle %.2f müNN; Gelände %.2f–%.2f müNN (Mittel %.2f), "
               + "mittlere Abtragstiefe %.2f m. Geometrisches Volumen im gewachsenen Zustand, "
               + "ohne Auflockerung.",
               flaecheM2, ausschnitt.breite, ausschnitt.tiefe, sohleMuNN,
               gelaendeMin, gelaendeMax, gelaendeMittel, mittlereTiefe)
    }
}

enum Aushubrechner {

    /// Aushub für einen Baukörper: Geländepunkte (in m, müNN) gegen die Sohle,
    /// über den Umriss plus Arbeitsraum.
    static func rechne(gelaende punkte: [(x: Double, y: Double, z: Double)],
                       umriss roh: Umriss,
                       vorgabe: Aushubvorgabe,
                       zellgroesse: Double = 0.25) -> Aushubergebnis? {
        let ausschnitt = roh.erweitert(um: vorgabe.arbeitsraum)
        guard let raster = Gelaendemodell.ausPunktwolke(punkte, ausschnitt: ausschnitt,
                                                        zellgroesse: zellgroesse) else { return nil }
        let massen = ErdmassenRechner.gegenEbene(raster.modell, zielHoehe: vorgabe.sohleMuNN)
        return Aushubergebnis(
            sohleMuNN: vorgabe.sohleMuNN,
            ausschnitt: ausschnitt,
            flaecheM2: raster.modell.flaeche,
            gelaendeMin: raster.modell.minHoehe,
            gelaendeMax: raster.modell.maxHoehe,
            gelaendeMittel: raster.modell.mittlereHoehe,
            abtragM3: massen.abtragM3,
            auftragM3: massen.auftragM3,
            zellenOhneTreffer: raster.zellenOhneTreffer,
            rasterHinweis: raster.hinweis)
    }

    /// Höhenversatz, der ein Modell mit eigener Null auf müNN hebt:
    /// „dieser Z-Wert im Modell ist in Wirklichkeit diese Höhe".
    static func hoehenversatz(modellZ: Double, entsprichtMuNN: Double) -> Double {
        entsprichtMuNN - modellZ
    }
}
