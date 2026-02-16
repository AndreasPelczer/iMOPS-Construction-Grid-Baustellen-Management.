//
//  KnowledgeDetailRouter.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI
import CoreData

struct KnowledgeDetailRouter: View {
    @Environment(\.managedObjectContext) private var ctx
    let item: KnowledgeItem

    var body: some View {
        switch item {
        case .product(let id):
            if let p = try? ctx.existingObject(with: id) as? CDProduct {
                ProductKnowledgeDetailView(product: p)
            } else {
                ContentUnavailableView("Nicht gefunden", systemImage: "exclamationmark.triangle")
            }

        case .lexikon(let id):
            if let e = try? ctx.existingObject(with: id) as? CDLexikonEntry {
                LexikonKnowledgeDetailView(entry: e)
            } else {
                ContentUnavailableView("Nicht gefunden", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
