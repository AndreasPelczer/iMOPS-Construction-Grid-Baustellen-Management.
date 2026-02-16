//
//  InfoBlock.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

// Dieser Baustein steht jetzt allen Views (MainView, AIDetailView, etc.) zur Verfügung
struct InfoBlock: View {
    let title: String
    let value: String
    let icon: String
    let color: Color 

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            Text(value)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }
}