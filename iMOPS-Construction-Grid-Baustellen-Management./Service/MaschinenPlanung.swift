//
//  MaschinenPlanung.swift
//  Nordstern-Stufe 3+4 verkettet: aus den Erdbau-Positionen des LV (Aushub in m³) wird
//  der Maschineneinsatz — Bagger-Stunden = Aushubmenge ÷ Leistung (`Erdbauleistung`).
//  Die Leistung kommt aus einem Gerät (`Geraet.leistung`, m³/h) oder, wenn keins gesetzt
//  ist, aus dem Richtwert (Minibagger 4,4 m³/h) — nachvollziehbar, nicht geraten.
//
//  EHRLICH: die Aushubmenge wird aus dem LV ERKANNT (KG 31x „Baugrube/Aushub" oder
//  Stichwörter), das ist eine Folgerung — sichtbar als solche.
//

import Foundation
import CoreData

struct MaschinenPlanung {

    let aushubM3: Double
    let leistungM3h: Double
    let quelleLeistung: String      // "Minibagger (Richtwert)" oder Gerätename
    let erdbauPositionen: Int

    /// Bagger-Stunden = Aushubmenge ÷ Leistung.
    var baggerStunden: Double { Erdbauleistung.stunden(menge: aushubM3, leistung: leistungM3h) }

    /// Grobe Bagger-Tage (bei 8 h/Tag).
    var baggerTage: Double { baggerStunden / 8.0 }

    var hatAushub: Bool { aushubM3 > 0 }

    /// Erkennt eine Erdbau-/Aushub-Position: DIN-276-KG 31x (Baugrube/Aushub) ODER ein
    /// Stichwort im Text — und Einheit m³.
    static func istAushub(_ p: LVPosition) -> Bool {
        guard (p.einheit ?? "").lowercased().contains("m³") else { return false }
        if (p.kostenGruppeNummer ?? "").hasPrefix("31") { return true }
        let t = (p.bezeichnung ?? "").folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return ["aushub", "baugrube", "oberboden", "erdaushub", "erdhub", "abtragen"].contains { t.contains($0) }
    }

    /// Maschineneinsatz aus den LV-Positionen einer Baustelle. `leistung`/`quelle` geben
    /// die zugrunde gelegte m³/h an (Gerät oder Richtwert).
    static func fuer(positionen: [LVPosition],
                     leistung: Double = Erdbauleistung.minibagger,
                     quelle: String = "Minibagger (Richtwert)") -> MaschinenPlanung {
        let erd = positionen.filter { istAushub($0) }
        let aushub = erd.reduce(0.0) { $0 + $1.menge }
        return MaschinenPlanung(aushubM3: aushub,
                                leistungM3h: leistung > 0 ? leistung : Erdbauleistung.minibagger,
                                quelleLeistung: quelle,
                                erdbauPositionen: erd.count)
    }
}
