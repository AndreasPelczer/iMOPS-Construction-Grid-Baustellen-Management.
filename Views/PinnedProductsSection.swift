import SwiftUI
import CoreData

// MARK: - Pinned Products

struct PinnedProductsSection: View {
    @Environment(\.managedObjectContext) private var ctx

    private let productIDs: [String]

    // Wir holen ALLE gepinnten Produkte in einem Fetch (performant),
    // bauen danach ein Dictionary für schnellen Zugriff.
    @FetchRequest private var fetched: FetchedResults<CDProduct>

    init(productIDs: [String]) {
        self.productIDs = productIDs

        // Wenn leer -> leere Predicate, damit FetchRequest gültig bleibt.
        let predicate: NSPredicate
        if productIDs.isEmpty {
            predicate = NSPredicate(value: false)
        } else {
            predicate = NSPredicate(format: "id IN %@", productIDs)
        }

        _fetched = FetchRequest<CDProduct>(
            sortDescriptors: [
                // Sort ist hier egal, weil wir später in "Pin-Reihenfolge" ausgeben.
                // Trotzdem stabil halten:
                NSSortDescriptor(keyPath: \CDProduct.name, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        if productIDs.isEmpty { return AnyView(EmptyView()) }

        // Map: id -> CDProduct (falls Duplikate existieren, nimmt Dictionary “den letzten”
        // aus der Iteration; darum kümmern wir uns unten bei "Unique Constraints".)
        let map: [String: CDProduct] = Dictionary(
            uniqueKeysWithValues: fetched.compactMap { p in
                guard let id = p.id else { return nil }
                return (id, p)
            }
        )

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("📌 Gepinnte Produkte")
                    .font(.headline)

                ForEach(productIDs, id: \.self) { id in
                    if let product = map[id] {
                        NavigationLink {
                            ProductKnowledgeDetailView(product: product)
                        } label: {
                            ProductKnowledgeRow(product: product)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Falls Pin auf etwas zeigt, das nicht mehr existiert:
                        Text("⚠️ Produkt nicht gefunden: \(id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }
}

// MARK: - Pinned Lexikon

struct PinnedLexikonSection: View {
    @Environment(\.managedObjectContext) private var ctx

    private let codes: [String]
    @FetchRequest private var fetched: FetchedResults<CDLexikonEntry>

    init(codes: [String]) {
        self.codes = codes

        let predicate: NSPredicate
        if codes.isEmpty {
            predicate = NSPredicate(value: false)
        } else {
            predicate = NSPredicate(format: "code IN %@", codes)
        }

        _fetched = FetchRequest<CDLexikonEntry>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        if codes.isEmpty { return AnyView(EmptyView()) }

        let map: [String: CDLexikonEntry] = Dictionary(
            uniqueKeysWithValues: fetched.compactMap { e in
                guard let code = e.code else { return nil }
                return (code, e)
            }
        )

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("📌 Gepinntes Lexikon")
                    .font(.headline)

                ForEach(codes, id: \.self) { code in
                    if let entry = map[code] {
                        NavigationLink {
                            LexikonKnowledgeDetailView(entry: entry)
                        } label: {
                            LexikonKnowledgeRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("⚠️ Lexikon-Eintrag nicht gefunden: \(code)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        )
    }
}
