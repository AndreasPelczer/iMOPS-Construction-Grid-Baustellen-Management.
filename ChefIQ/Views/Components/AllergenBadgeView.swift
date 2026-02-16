//
//  AllergenBadgeView.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

struct AllergenBadgeView: View {
    let allergenCodes: String
    
    var body: some View {
        // Wir teilen den String bei den Kommas auf
        let codes = allergenCodes.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(codes, id: \.self) { code in
                    if let allergen = Allergen(rawValue: code) {
                        HStack(spacing: 4) {
                            Image(systemName: allergen.icon)
                                .font(.system(size: 10))
                            Text(allergen.name)
                                .font(.caption2).bold()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(allergen.color.opacity(0.2))
                        .foregroundColor(allergen.color)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(allergen.color.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}