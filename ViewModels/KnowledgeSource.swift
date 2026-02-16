//
//  KnowledgeSource.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI
import CoreData

enum KnowledgeSource: String, CaseIterable, Identifiable {
    case alle = "Alle"
    case natur = "Natur"
    case hering = "Hering"
    case lieferant = "Lieferant"
    var id: String { rawValue }
}

enum KnowledgeItem: Identifiable, Hashable {
    case product(NSManagedObjectID)
    case lexikon(NSManagedObjectID)

    var id: NSManagedObjectID {
        switch self {
        case .product(let id), .lexikon(let id): return id
        }
    }
}

struct KnowledgeHubView: View {
    @Environment(\.managedObjectContext) private var ctx

    @State private var source: KnowledgeSource = .alle
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Alle"

    @State private var categories: [String] = []
    @State private var results: [KnowledgeItem] = []

    var body: some View {
        List {
            Section {
                Picker("Quelle", selection: $source) {
                    ForEach(KnowledgeSource.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Suchen… (Name/Beschreibung/Code)", text: $searchText)
                    .textInputAutocapitalization(.never)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Alle")
                        ForEach(categories, id: \.self) { chip($0) }
                    }
                    .padding(.vertical, 6)
                }
                .listRowInsets(EdgeInsets())
            }

            Section("Ergebnisse") {
                if results.isEmpty {
                    ContentUnavailableView("Keine Treffer", systemImage: "magnifyingglass")
                } else {
                    ForEach(results, id: \.self) { item in
                        NavigationLink {
                            KnowledgeDetailRouter(item: item)
                        } label: {
                            KnowledgeRow(item: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("Knowledge")
        .onAppear {
            // Import nur 1x, wenn DB leer
            KnowledgeImporter.importIfNeeded(into: ctx)
            rebuildCategories()
            refreshResults()
        }
        .onChange(of: source) { refreshResults() }
        .onChange(of: searchText) { refreshResults() }
        .onChange(of: selectedCategory) { refreshResults() }
    }

    private func chip(_ title: String) -> some View {
        Button {
            selectedCategory = title
        } label: {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedCategory == title ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(selectedCategory == title ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func rebuildCategories() {
        // Kategorien: DISTINCT fetch (Products.category + Lexikon.kategorie)
        // Für MVP holen wir beide Listen klein via dictionaries.
        // (Wenn du >100k willst: wir machen später eine eigene Category-Entity oder SQLite DISTINCT.)
        let productCats = fetchDistinctStrings(entity: CDProduct.entity(), key: "category")
        let lexCats = fetchDistinctStrings(entity: CDLexikonEntry.entity(), key: "kategorie")
        categories = Array(Set(productCats + lexCats)).sorted()
    }

    private func fetchDistinctStrings(entity: NSEntityDescription, key: String) -> [String] {
        let req = NSFetchRequest<NSDictionary>()
        req.entity = entity
        req.resultType = .dictionaryResultType
        req.propertiesToFetch = [key]
        req.returnsDistinctResults = true

        do {
            let dicts = try ctx.fetch(req)
            return dicts.compactMap { $0[key] as? String }.filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private func refreshResults() {
        // Wir fetch’en IDs (objectIDs) in sinnvoller Batchgröße.
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cat = selectedCategory

        let productIDs = fetchProductIDs(term: term, category: cat, source: source)
        let lexIDs = fetchLexikonIDs(term: term, category: cat, source: source)

        // Merge (einfach hintereinander; später können wir sortieren)
        results = productIDs.map { .product($0) } + lexIDs.map { .lexikon($0) }
    }

    private func fetchProductIDs(term: String, category: String, source: KnowledgeSource) -> [NSManagedObjectID] {
        let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        req.fetchBatchSize = 80
        req.fetchLimit = 200

        var predicates: [NSPredicate] = []

        if source != .alle {
            predicates.append(NSPredicate(format: "dataSource == %@", source.rawValue))
        }
        if category != "Alle" {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        if !term.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@ OR beschreibung CONTAINS[cd] %@", term, term))
        }

        req.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            return try ctx.fetch(req).map { $0.objectID }
        } catch {
            return []
        }
    }

    private func fetchLexikonIDs(term: String, category: String, source: KnowledgeSource) -> [NSManagedObjectID] {
        // Lexikon ist „Hering“ in deiner Semantik (Wissen), aber du willst es trotzdem über „Alle“ sehen.
        // Wenn Quelle explizit Natur/Lieferant ist, verstecken wir Lexikon.
        if source == .natur || source == .lieferant { return [] }

        let req: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        req.fetchBatchSize = 80
        req.fetchLimit = 200

        var predicates: [NSPredicate] = []

        if category != "Alle" {
            predicates.append(NSPredicate(format: "kategorie == %@", category))
        }
        if !term.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@ OR code CONTAINS[cd] %@ OR beschreibung CONTAINS[cd] %@", term, term, term))
        }

        req.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            return try ctx.fetch(req).map { $0.objectID }
        } catch {
            return []
        }
    }
}
