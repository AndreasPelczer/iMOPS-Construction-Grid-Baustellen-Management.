//
//  SectionView.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

/// Ein universeller Container für die Detailansichten im ChefIQ-Design
struct SectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    // Initialisierer mit @ViewBuilder für flexibles Design innerhalb der Sektion
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            content
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }
}