//
//  KnowledgeHomeView.swift
//  test25B
//
//  Created by Andreas Pelczer on 13.01.26.
//


import SwiftUI
import CoreData

/// Modernes Knowledge-Home: Produkte + Lexikon, Suche, schöner Look (iOS 15 kompatibel).
struct KnowledgeHomeView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case products = "Produkte"
        case lexikon = "Lexikon"
        var id: String { rawValue }
    }

    @Environment(\.managedObjectContext) private var context

    @State private var mode: Mode = .products
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Alle"

    var body: some View {
        VStack(spacing: 0) {

            // Segmented Control
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)

            // Kategorie Filter (optional)
            CategoryBar(
                mode: mode,
                searchText: searchText,
                selectedCategory: $selectedCategory
            )
            .padding(.horizontal)
            .padding(.top, 8)

            // Liste
            Group {
                if mode == .products {
                    ProductListView(searchText: searchText, category: selectedCategory)
                } else {
                    LexikonListView(searchText: searchText, category: selectedCategory)
                }
            }
        }
        .navigationTitle("Wissen")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Suchen (Name, Code, Kategorie…)")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !searchText.isEmpty {
                    Button("Leeren") { searchText = "" }
                }
            }
        }
        .onAppear {
            print("📍 KnowledgeHomeView erschienen -> starte ImportIfNeeded")
            KnowledgeImporter.importIfNeeded(into: context)
        }
    }
}

private struct CategoryBar: View {
    @Environment(\.managedObjectContext) private var context

    let mode: KnowledgeHomeView.Mode
    let searchText: String
    @Binding var selectedCategory: String

    @State private var categories: [String] = ["Alle"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    Button(action: { selectedCategory = cat }) {
                        Text(cat)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == cat ? Color.primary.opacity(0.12) : Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
        .onAppear { refreshCategories() }
        .onChange(of: mode) {
            selectedCategory = "Alle"
            refreshCategories()
        }
    }

    /// Lädt Kategorien (simpel + robust) aus Core Data.
    private func refreshCategories() {
        var set = Set<String>()
        set.insert("Alle")

        if mode == .products {
            let req: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
            req.fetchBatchSize = 500
            req.returnsObjectsAsFaults = true
            req.includesPropertyValues = true

            if let result = try? context.fetch(req) {
                for p in result {
                    if let c = p.category, !c.isEmpty { set.insert(c) }
                }
            }
        } else {
            let req: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
            req.fetchBatchSize = 500
            req.returnsObjectsAsFaults = true
            req.includesPropertyValues = true

            if let result = try? context.fetch(req) {
                for e in result {
                    if let c = e.kategorie, !c.isEmpty { set.insert(c) }
                }
            }
        }

        categories = Array(set).sorted { a, b in
            if a == "Alle" { return true }
            if b == "Alle" { return false }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }
}
