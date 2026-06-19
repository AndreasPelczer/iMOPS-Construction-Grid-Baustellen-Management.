//
//  Untitled.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 19.06.26.
//

import Foundation

struct GelaendeResult: Codable {
    let status: String
    let quelle: String
    let n_stuetzstellen: Int
    let flurstueck_m2: Int
    let haus_m2: Double
    let haus_b: Double
    let haus_l: Double
    let gelaende_min: Double
    let gelaende_max: Double
    let gelaende_delta: Double
    let okbp: Double
    let cut: Double
    let fill: Double
    let schotter_t: Double
    let vlies_m2: Int
    let sens_m3: Double
    let sens_lkw: Int
    let meldung: String
}
