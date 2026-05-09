import SwiftUI

struct KostenGruppePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: DIN276KostenGruppe?

    @State private var searchText = ""

    private let grouped: [(String, [DIN276KostenGruppe])] = {
        let prefixes = ["3", "4", "5"]
        return prefixes.map { prefix in
            let titel: String
            switch prefix {
            case "3": titel = "KG 300 – Baukonstruktionen"
            case "4": titel = "KG 400 – Technische Anlagen"
            default:  titel = "KG 500 – Außenanlagen"
            }
            let items = DIN276KostenGruppe.alle.filter { $0.nummer.hasPrefix(prefix) }
            return (titel, items)
        }
    }()

    private var filtered: [(String, [DIN276KostenGruppe])] {
        guard !searchText.isEmpty else { return grouped }
        let q = searchText.lowercased()
        return grouped.compactMap { (header, items) in
            let hits = items.filter {
                $0.nummer.contains(q) || $0.bezeichnung.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : (header, hits)
        }
    }

    var body: some View {
        List {
            Button {
                selection = nil
                dismiss()
            } label: {
                HStack {
                    Text("Keine Zuordnung").foregroundStyle(.primary)
                    Spacer()
                    if selection == nil {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
            }

            ForEach(filtered, id: \.0) { header, items in
                Section(header) {
                    ForEach(items) { kg in
                        Button {
                            selection = kg
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kg.nummer).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(kg.bezeichnung).foregroundStyle(.primary)
                                }
                                Spacer()
                                if selection?.id == kg.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "KG-Nummer oder Bezeichnung suchen")
        .navigationTitle("Kostengruppe (DIN 276)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
