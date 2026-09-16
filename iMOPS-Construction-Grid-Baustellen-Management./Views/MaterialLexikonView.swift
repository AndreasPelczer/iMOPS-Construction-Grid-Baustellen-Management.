import SwiftUI
import Combine
import CoreData

struct MaterialLexikonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var materials: FetchedResults<CDLexikonEntry>

    @ObservedObject private var lager = LagerStore.shared
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
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink { LagerView() } label: {
                    Label("Lager", systemImage: "shippingbox")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMaterialView()
                .presentationSizing(.page)
        }
    }

    private func materialRow(_ entry: CDLexikonEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForKategorie(entry.kategorie))
                .font(.title3)
                .foregroundStyle(.tint)
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
            Spacer()
            lagerBadge(for: entry.code)
        }
    }

    /// „X auf Lager", wenn für diesen Katalog-Artikel ein Bestand gebucht ist.
    @ViewBuilder
    private func lagerBadge(for code: String?) -> some View {
        if let code, !code.isEmpty {
            let bestand = lager.gesamtbestand(artikelCode: code)
            if bestand > 0.0001 {
                let einheit = lager.artikelImLager().first { $0.code == code }?.einheit ?? ""
                Text("\(bestand.formatted(.number.precision(.fractionLength(0...2)))) \(einheit) auf Lager")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.green.opacity(0.14), in: Capsule())
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
                .background(isSelected ? Color(uiColor: .tintColor) : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
