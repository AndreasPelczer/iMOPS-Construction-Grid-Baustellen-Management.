import SwiftUI
import CoreData

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest private var products: FetchedResults<CDProduct>

    private let searchText: String
    private let category: String

    init(searchText: String, category: String) {
        self.searchText = searchText
        self.category = category

        let predicate = ProductListView.makePredicate(searchText: searchText, category: category)

        let request: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CDProduct.category, ascending: true),
            NSSortDescriptor(keyPath: \CDProduct.name, ascending: true)
        ]
        request.predicate = predicate
        request.fetchBatchSize = 80
        request.returnsObjectsAsFaults = true

        _products = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        listBody
            .scrollContentBackground(.hidden)
    }

    // ✅ ausgelagert, damit wir nicht doppeln müssen
    private var listBody: some View {
        List {
            if products.isEmpty {
                EmptyStateView(
                    title: "Keine Produkte",
                    subtitle: "Passe Suche oder Kategorie an."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } else {

                Text("Treffer: \(products.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))

                ForEach(products, id: \.objectID) { product in
                    NavigationLink(destination: ProductKnowledgeDetailView(product: product)) {
                        ProductKnowledgeRow(product: product)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteProduct(product)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .padding(.top, 6)
    }

    private func deleteProduct(_ product: CDProduct) {
        ctx.delete(product)
        do { try ctx.save() } catch { print("Produkt löschen Fehler: \(error)") }
    }

    private static func makePredicate(searchText: String, category: String) -> NSPredicate? {
        var preds: [NSPredicate] = []

        if category != "Alle" {
            preds.append(NSPredicate(format: "category == %@", category))
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            preds.append(
                NSPredicate(format: "(name CONTAINS[cd] %@) OR (category CONTAINS[cd] %@) OR (dataSource CONTAINS[cd] %@)",
                            q, q, q)
            )
        }

        if preds.isEmpty { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: preds)
    }
}
