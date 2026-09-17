//
//  Erdmassen.swift
//  Bogen 1 (Nordstern-Stufe 3, Geländebrücke): aus dem Gelände die Erdmassen rechnen —
//  Abtrag (Cut) und Auftrag (Fill) — statt die Aushubmenge zu raten.
//
//  Das Gelände kommt als Raster (DGM1: 1 m Gitter, Höhen in m). Gegen ein Planum
//  (Aushubsohle/Zielhöhe) wird je Zelle die Höhendifferenz mal Zellfläche gerechnet
//  und aufsummiert (Prismen-/Rastermethode). Der Abtrag ist die Aushubmenge, die dann
//  durch die vorhandene Kette läuft: MaschinenPlanung → Bagger-Stunden → Miete (A) → Brigade (B).
//
//  EHRLICH (Tao): das ist eine SCHÄTZUNG aus offenen Höhendaten, kein Vermesser-Aufmaß.
//  Fester/gewachsener Boden vs. gelöster Boden (Auflockerung) ist NICHT eingerechnet —
//  der Abtrag ist das geometrische Volumen im gewachsenen Zustand.
//

import Foundation

// MARK: - Geländemodell (Höhenraster)

struct Gelaendemodell {
    /// Höhen in Metern, Zeilen (y) × Spalten (x). Rechteckig, mindestens 1×1.
    let hoehen: [[Double]]
    let dx: Double          // Zellbreite in m (DGM1: 1,0)
    let dy: Double          // Zelltiefe in m

    init?(hoehen: [[Double]], dx: Double = 1.0, dy: Double = 1.0) {
        guard dx > 0, dy > 0, let erste = hoehen.first, !erste.isEmpty,
              hoehen.allSatisfy({ $0.count == erste.count }) else { return nil }
        self.hoehen = hoehen; self.dx = dx; self.dy = dy
    }

    var zellen: Int { hoehen.reduce(0) { $0 + $1.count } }
    var zellflaeche: Double { dx * dy }
    var flaeche: Double { Double(zellen) * zellflaeche }
    var alleHoehen: [Double] { hoehen.flatMap { $0 } }
    var minHoehe: Double { alleHoehen.min() ?? 0 }
    var maxHoehe: Double { alleHoehen.max() ?? 0 }
    /// Mittlere Geländehöhe = die Massenausgleichs-Höhe (Cut = Fill, minimaler Abtransport).
    var mittlereHoehe: Double {
        let h = alleHoehen
        return h.isEmpty ? 0 : h.reduce(0, +) / Double(h.count)
    }
}

// MARK: - Ergebnis

struct Erdmassen {
    let abtragM3: Double        // Cut — was gelöst/abgefahren wird (= Aushubmenge)
    let auftragM3: Double       // Fill — was aufgefüllt/eingebaut werden muss
    let flaecheM2: Double
    let zellen: Int

    /// Netto: positiv = Überschuss (abfahren), negativ = Defizit (Boden liefern).
    var nettoM3: Double { abtragM3 - auftragM3 }
    /// Die Aushubmenge, die in die LV-/Maschinen-Kette geht (= Abtrag).
    var aushubM3: Double { abtragM3 }
}

// MARK: - Rechner

enum ErdmassenRechner {

    /// Erdmassen gegen ein waagerechtes Planum (feste Zielhöhe, z.B. Aushubsohle/OK Bodenplatte).
    /// Zelle über dem Planum → Abtrag, Zelle darunter → Auftrag.
    static func gegenEbene(_ dgm: Gelaendemodell, zielHoehe: Double) -> Erdmassen {
        let zelle = dgm.zellflaeche
        var cut = 0.0, fill = 0.0
        for zeile in dgm.hoehen {
            for h in zeile {
                let d = h - zielHoehe
                if d > 0 { cut += d * zelle } else { fill += -d * zelle }
            }
        }
        return Erdmassen(abtragM3: cut, auftragM3: fill, flaecheM2: dgm.flaeche, zellen: dgm.zellen)
    }

    /// Erdmassen gegen eine geplante Zielfläche (zweites Raster gleicher Größe, z.B. geplante
    /// Geländeoberkante). nil, wenn die Raster nicht zusammenpassen.
    static func gegenFlaeche(_ dgm: Gelaendemodell, ziel: Gelaendemodell) -> Erdmassen? {
        guard dgm.hoehen.count == ziel.hoehen.count,
              zip(dgm.hoehen, ziel.hoehen).allSatisfy({ $0.count == $1.count }),
              dgm.dx == ziel.dx, dgm.dy == ziel.dy else { return nil }
        let zelle = dgm.zellflaeche
        var cut = 0.0, fill = 0.0
        for (zeileIst, zeileZiel) in zip(dgm.hoehen, ziel.hoehen) {
            for (h, z) in zip(zeileIst, zeileZiel) {
                let d = h - z
                if d > 0 { cut += d * zelle } else { fill += -d * zelle }
            }
        }
        return Erdmassen(abtragM3: cut, auftragM3: fill, flaecheM2: dgm.flaeche, zellen: dgm.zellen)
    }

    /// Massenausgleich: das waagerechte Planum, bei dem Abtrag = Auftrag (mittlere Höhe).
    /// Der Aushub, den man NICHT abfahren muss, weil er vor Ort wieder eingebaut wird.
    static func massenausgleich(_ dgm: Gelaendemodell) -> (hoehe: Double, massen: Erdmassen) {
        let h = dgm.mittlereHoehe
        return (h, gegenEbene(dgm, zielHoehe: h))
    }
}

// MARK: - DGM1-XYZ-Parser

extension Gelaendemodell {

    /// Baut ein Höhenraster aus DGM1-XYZ-Text ("x y z" je Zeile, Bayern-Open-Data-Format).
    /// Rekonstruiert das Gitter aus den sortierten X/Y-Koordinaten; die Auflösung (dx/dy)
    /// ergibt sich aus dem kleinsten Koordinatenabstand. Lücken werden mit `fehlwert` gefüllt.
    static func ausXYZ(_ text: String, fehlwert: Double? = nil) -> Gelaendemodell? {
        var punkte: [(x: Double, y: Double, z: Double)] = []
        for zeile in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let f = zeile.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == ";" || $0 == "," })
            guard f.count >= 3,
                  let x = Double(f[0]), let y = Double(f[1]), let z = Double(f[2]) else { continue }
            punkte.append((x, y, z))
        }
        guard punkte.count >= 4 else { return nil }

        let xs = Array(Set(punkte.map { runden($0.x) })).sorted()
        let ys = Array(Set(punkte.map { runden($0.y) })).sorted()
        guard xs.count >= 2, ys.count >= 2 else { return nil }
        let dx = minAbstand(xs), dy = minAbstand(ys)
        guard dx > 0, dy > 0 else { return nil }

        // Index über gerundete Koordinaten.
        let xIndex = Dictionary(uniqueKeysWithValues: xs.enumerated().map { ($1, $0) })
        let yIndex = Dictionary(uniqueKeysWithValues: ys.enumerated().map { ($1, $0) })
        var gitter = [[Double?]](repeating: [Double?](repeating: nil, count: xs.count), count: ys.count)
        for p in punkte {
            if let iy = yIndex[runden(p.y)], let ix = xIndex[runden(p.x)] { gitter[iy][ix] = p.z }
        }

        // Y absteigend (Norden oben), Lücken füllen.
        let fw = fehlwert
        var hoehen: [[Double]] = []
        for iy in stride(from: ys.count - 1, through: 0, by: -1) {
            var zeile: [Double] = []
            for ix in 0..<xs.count {
                if let z = gitter[iy][ix] { zeile.append(z) }
                else if let fw { zeile.append(fw) }
                else { return nil }   // Lücke ohne Fehlwert → kein sauberes Raster
            }
            hoehen.append(zeile)
        }
        return Gelaendemodell(hoehen: hoehen, dx: dx, dy: dy)
    }

    private static func runden(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
    private static func minAbstand(_ sortiert: [Double]) -> Double {
        var m = Double.greatestFiniteMagnitude
        for i in 1..<sortiert.count { m = min(m, sortiert[i] - sortiert[i - 1]) }
        return m == .greatestFiniteMagnitude ? 0 : m
    }
}
