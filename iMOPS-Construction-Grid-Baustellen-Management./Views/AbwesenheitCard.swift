//
//  AbwesenheitCard.swift
//  Beim Mitarbeiter: wann er nicht da ist. Eintragen, ansehen, löschen – mehr nicht.
//

import SwiftUI

struct AbwesenheitCard: View {
    let name: String
    @ObservedObject private var store = AbwesenheitenStore.shared
    @State private var neu = false
    @State private var von = Date()
    @State private var bis = Date()
    @State private var art: Abwesenheit.Art = .urlaub
    @State private var loeschen: Abwesenheit?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Nicht da", systemImage: "beach.umbrella").font(.headline)
                Spacer()
                Button { neu.toggle() } label: { Image(systemName: neu ? "xmark.circle" : "plus.circle.fill") }
            }
            let liste = store.von(name)
            if liste.isEmpty && !neu {
                Text("Kein Urlaub eingetragen.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(liste) { a in
                HStack {
                    Text(a.art.anzeige).font(.subheadline.weight(.semibold))
                    Text(a.zeitraum).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) { loeschen = a } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
            if neu {
                Picker("Art", selection: $art) {
                    ForEach(Abwesenheit.Art.allCases) { Text($0.anzeige).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("von", selection: $von, displayedComponents: .date)
                DatePicker("bis", selection: $bis, in: von..., displayedComponents: .date)
                Text("Nur ob jemand da ist – kein Grund. „krank“ gehört nicht hierher.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Eintragen") {
                    store.hinzu(Abwesenheit(name: name, von: von, bis: max(bis, von), art: art))
                    neu = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Eintrag löschen?", isPresented: Binding(get: { loeschen != nil }, set: { if !$0 { loeschen = nil } })) {
            Button("Löschen", role: .destructive) { if let a = loeschen { store.entferne(a) }; loeschen = nil }
            Button("Behalten", role: .cancel) { loeschen = nil }
        } message: {
            Text(loeschen.map { "\($0.art.anzeige) \($0.zeitraum) von \(name)." } ?? "")
        }
    }
}
