//
//  LexikonListView.swift
//  test25B
//
//  Created by Andreas Pelczer on 13.01.26.
//

import SwiftUI
import CoreData

struct LexikonListView: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest private var entries: FetchedResults<CDLexikonEntry>

    private let searchText: String
    private let category: String

    init(searchText: String, category: String) {
        self.searchText = searchText
        self.category = category

        let predicate = LexikonListView.makePredicate(searchText: searchText, category: category)

        let request: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
        request.predicate = predicate
        request.fetchBatchSize = 120
        request.returnsObjectsAsFaults = true

        _entries = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            if entries.isEmpty {
                EmptyStateView(
                    title: "Keine Einträge",
                    subtitle: "Passe Suche oder Kategorie an."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } else {

                Text("Treffer: \(entries.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))

                ForEach(entries, id: \.objectID) { e in
                    NavigationLink(destination: LexikonKnowledgeDetailView(entry: e)) {
                        LexikonKnowledgeRow(entry: e)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteLexikon(e)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden) // ✅ jetzt ok, da iOS 16+
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .padding(.top, 6)
    }

    private func deleteLexikon(_ entry: CDLexikonEntry) {
        ctx.delete(entry)
        do { try ctx.save() } catch { print("Lexikon löschen Fehler: \(error)") }
    }

    private static func makePredicate(searchText: String, category: String) -> NSPredicate? {
        var preds: [NSPredicate] = []

        if category != "Alle" {
            preds.append(NSPredicate(format: "kategorie == %@", category))
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            preds.append(
                NSPredicate(format: "(name CONTAINS[cd] %@) OR (code CONTAINS[cd] %@) OR (kategorie CONTAINS[cd] %@) OR (beschreibung CONTAINS[cd] %@)",
                            q, q, q, q)
            )
        }

        if preds.isEmpty { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: preds)
    }
}
