import SwiftUI
internal import CoreData

struct MaterialLexikonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var materials: FetchedResults<CDLexikonEntry>

    @State private var searchText = ""
    @State private var selectedKategorie: String?
    @State private var showingAddSheet = false

    private var kategorien: [String] {
        Set(materials.compactMap { $0.kategorie }).sorted()
    }

    private var filtered: [CDLexikonEntry] {
        var result = Array(materials)
        if let kat = selectedKategorie {
            result = result.filter { $0.kategorie == kat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                ($0.name ?? "").lowercased().contains(q) ||
                ($0.code ?? "").lowercased().contains(q) ||
                ($0.beschreibung ?? "").lowercased().contains(q)
            }
        }
        return result
    }

    private var grouped: [(String, [CDLexikonEntry])] {
        Dictionary(grouping: filtered, by: { $0.kategorie ?? "Sonstige" })
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        List {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Alle", isSelected: selectedKategorie == nil) {
                        selectedKategorie = nil
                    }
                    ForEach(kategorien, id: \.self) { kat in
                        FilterChip(title: kat, isSelected: selectedKategorie == kat) {
                            selectedKategorie = kat
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(grouped, id: \.0) { category, items in
                Section(category) {
                    ForEach(items, id: \.objectID) { entry in
                        NavigationLink {
                            MaterialDetailView(material: entry)
                        } label: {
                            materialRow(entry)
                        }
                    }
                    .onDelete { offsets in
                        deleteMaterials(items: items, at: offsets)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Name, Code oder Beschreibung...")
        .navigationTitle("Katalog")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMaterialView()
        }
    }

    private func materialRow(_ entry: CDLexikonEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForKategorie(entry.kategorie))
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name ?? "").font(.body)
                HStack(spacing: 8) {
                    Text(entry.code ?? "")
                        .font(.caption).foregroundStyle(.secondary)
                    if let beschr = entry.beschreibung, !beschr.isEmpty {
                        Text("\u{2022}").foregroundStyle(.secondary)
                        Text(beschr).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }

    private func iconForKategorie(_ kat: String?) -> String {
        switch kat {
        case "Rohbau":      return "building.2"
        case "Trockenbau":  return "square.split.2x2"
        case "Elektro":     return "bolt.fill"
        case "Sanitaer":    return "drop.fill"
        case "Daemmung":    return "shield.fill"
        case "Ausbau":      return "paintbrush.fill"
        default:            return "shippingbox"
        }
    }

    private func deleteMaterials(items: [CDLexikonEntry], at offsets: IndexSet) {
        for idx in offsets {
            viewContext.delete(items[idx])
        }
        try? viewContext.save()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
