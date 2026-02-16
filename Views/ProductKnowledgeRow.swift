//
//  ProductKnowledgeRow.swift
//  test25B
//
//  Created by Andreas Pelczer on 13.01.26.
//


import SwiftUI
import CoreData

struct ProductKnowledgeRow: View {
    @ObservedObject var product: CDProduct

    var body: some View {
        HStack(spacing: 12) {
            // Icon Block
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.12))
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name ?? "Unbenannt")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let cat = product.category, !cat.isEmpty {
                        Badge(text: cat, systemImage: "tag.fill")
                    }
                    if let src = product.dataSource, !src.isEmpty {
                        Badge(text: src, systemImage: "bolt.fill")
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
