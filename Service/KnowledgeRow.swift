//
//  KnowledgeRow.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI
import CoreData

struct KnowledgeRow: View {
    @Environment(\.managedObjectContext) private var ctx
    let item: KnowledgeItem

    var body: some View {
        switch item {
        case .product(let id):
            let p = (try? ctx.existingObject(with: id) as? CDProduct)
            HStack {
                RoundedRectangle(cornerRadius: 2).fill(.blue).frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text((p?.name ?? "Produkt").uppercased()).bold()
                    Text(p?.category ?? "").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(p?.dataSource ?? "")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(6)
            }

        case .lexikon(let id):
            let e = (try? ctx.existingObject(with: id) as? CDLexikonEntry)
            HStack {
                RoundedRectangle(cornerRadius: 2).fill(.orange).frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text((e?.name ?? "Lexikon").uppercased()).bold()
                    Text(e?.kategorie ?? "Fachbuch").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(e?.code ?? "")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(6)
            }
        }
    }
}
