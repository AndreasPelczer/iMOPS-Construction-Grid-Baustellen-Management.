import SwiftUI

struct KGPickerList: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    let kgs: [(nr: String, name: String)] = [
        ("100","Grundstück"),("200","Herrichten & Erschließen"),
        ("300","Baukonstruktionen"),("310","Baugrube"),("320","Gründung"),
        ("330","Außenwände"),("340","Innenwände"),("350","Decken"),
        ("360","Dächer"),("370","Infrastruktur"),("380","Fenster & Türen"),
        ("390","Sonstige Baukonstruktion"),("400","Technische Anlagen"),
        ("410","Abwasser, Wasser, Gas"),("420","Wärmeversorgung"),
        ("430","Lufttechnische Anlagen"),("440","Starkstrom"),
        ("450","Fernmelde- & IT-Anlagen"),("500","Außenanlagen"),
        ("600","Ausstattung"),("700","Baunebenkosten")
    ]

    var body: some View {
        List(kgs, id: \.nr) { kg in
            Button { selected = kg.nr; dismiss() } label: {
                HStack {
                    Text("KG \(kg.nr)").font(.body.monospacedDigit()).foregroundStyle(.primary)
                    Text(kg.name).foregroundStyle(.secondary)
                    Spacer()
                    if selected == kg.nr { Image(systemName: "checkmark").foregroundStyle(.orange) }
                }
            }
        }
        .navigationTitle("Kostengruppe wählen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct KatalogPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let onSelect: (CDLexikonEntry) -> Void

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var entries: FetchedResults<CDLexikonEntry>

    @State private var search = ""

    private var filtered: [CDLexikonEntry] {
        guard !search.isEmpty else { return Array(entries) }
        let q = search.lowercased()
        return entries.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            ($0.code ?? "").lowercased().contains(q) ||
            ($0.kategorie ?? "").lowercased().contains(q)
        }
    }

    private var grouped: [(String, [CDLexikonEntry])] {
        Dictionary(grouping: filtered, by: { $0.kategorie ?? "Sonstige" }).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { kat, items in
                    Section(kat) {
                        ForEach(items, id: \.objectID) { entry in
                            Button { onSelect(entry); dismiss() } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name ?? "").foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        Text(entry.code ?? "").font(.caption).foregroundStyle(.secondary)
                                        if let d = entry.details, !d.isEmpty {
                                            Text("·").foregroundStyle(.secondary)
                                            Text(d).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Artikel suchen...")
            .navigationTitle("Katalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }
}

