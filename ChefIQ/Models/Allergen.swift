//
//  Allergen.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

enum Allergen: String, CaseIterable {
    case A = "A", C = "C", D = "D", F = "F", G = "G", H = "H", I = "I", J = "J", K = "K", L = "L", M = "M", N = "N", P = "P", R = "R"
    
    var name: String {
        switch self {
        case .A: return "Gluten"
        case .C: return "Ei"
        case .D: return "Fisch"
        case .F: return "Soja"
        case .G: return "Milch/Laktose"
        case .H: return "Schalenfrüchte"
        case .I: return "Sellerie"
        case .J: return "Senf"
        case .K: return "Sesam"
        case .L: return "Sulfite"
        case .M: return "Lupine"
        case .N: return "Weichtiere"
        default: return "Unbekannt"
        }
    }
    
    var icon: String {
        switch self {
        case .A: return "leaf.fill"
        case .C: return "egg.fill"
        case .D: return "fish.fill"
        case .G: return "drop.fill"
        case .L: return "ivfluid.bag.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .A, .G: return .orange
        case .D: return .blue
        case .C: return .yellow
        default: return .secondary
        }
    }
}