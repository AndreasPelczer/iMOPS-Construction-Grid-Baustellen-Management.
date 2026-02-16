//
//  KnowledgeHubView.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

/// Diese View zeigt die gesammelten Fakten von Wikipedia, DGE und anderen Quellen an.
struct QuellenHubView: View {
    let begriff: String
    let fakten: [QuellenInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Die Überschrift mit klinischem Flair
            Label("Wissen & Quellen: \(begriff)", systemImage: "quote.opening")
                .font(.headline)
                .foregroundColor(.purple)
                .padding(.bottom, 4)

            // Wir gehen jeden einzelnen Fakt durch
            ForEach(fakten) { fakt in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        // Dynamisches Icon je nach Quelle
                        Image(systemName: iconForQuelle(fakt.quelle))
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        
                        Text(fakt.quelle)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    
                    Text(fakt.aussage)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true) // Verhindert abgeschnittenen Text
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }

    // Hilfsfunktion: Ordnet jeder Quelle ein passendes Star-Trek-artiges Icon zu
    private func iconForQuelle(_ quelle: String) -> String {
        let q = quelle.lowercased()
        if q.contains("wikipedia") { return "book.closed.fill" }
        if q.contains("dge") || q.contains("gesellschaft") { return "checkmark.seal.fill" }
        if q.contains("usda") || q.contains("klinik") { return "cross.case.fill" }
        return "info.bubble.fill"
    }
}