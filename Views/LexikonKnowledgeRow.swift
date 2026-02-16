//
//  LexikonKnowledgeRow.swift
//  test25B
//
//  Created by Andreas Pelczer on 13.01.26.
//


import SwiftUI
import CoreData

struct LexikonKnowledgeRow: View {
    @ObservedObject var entry: CDLexikonEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.12))
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name ?? "Unbenannt")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let code = entry.code, !code.isEmpty {
                        Badge(text: code, systemImage: "number")
                    }
                    if let kat = entry.kategorie, !kat.isEmpty {
                        Badge(text: kat, systemImage: "folder.fill")
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
