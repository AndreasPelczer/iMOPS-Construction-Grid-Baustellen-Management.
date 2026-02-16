//
//  OmniProduct.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 17.01.26.
//


import Foundation

struct OmniProduct: Identifiable, Codable {
    var id: String // Wir nutzen die ID aus der JSON (z.B. "A1-HUEHN-2026")
    let name: String
    let mumpsCategory: String
    let baseTemperature: Int
    let baseTime: Int
    let umamiFactor: Double
    let safetyNote: String
    
    // Kleiner Trick: SwiftUI braucht eine eindeutige ID
    var ident: String { id }
}