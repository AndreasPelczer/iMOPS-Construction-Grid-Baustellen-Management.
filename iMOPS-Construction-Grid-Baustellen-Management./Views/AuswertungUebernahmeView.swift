import SwiftUI
import CoreData

/// „Aus Unterlagen übernehmen": zeigt LV-Vorschläge aus den gespeicherten
/// Dokument-Auswertungen (aktuell Erschließung), gruppiert nach Quell-Dokument.
/// Du bestätigst jeden Vorschlag (Häkchen), Menge editierbar — nichts landet
/// automatisch im LV.
struct AuswertungUebernahmeView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var vorschlaege: [VorschlagLVPosition] = []
    @State private var geladen = false

    private var selektierteAnzahl: Int { vorschlaege.filter(\.istSelektiert).count }

    /// Indizes gruppiert nach Quell-Dokument (ein Abschnitt je PDF).
    private var gruppen: [(datei: String, indizes: [Int])] {
        let paare = vorschlaege.indices.map { (i: $0, name: vorschlaege[$0].quellDatei) }
        let dict = Dictionary(grouping: paare, by: { $0.name })
        return dict.keys.sorted().map { name in (datei: name, indizes: dict[name]!.map { $0.i }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vorschlaege.isEmpty {
                    ContentUnavailableView(
                        "Nichts zu übernehmen",
                        systemImage: "tray",
                        description: Text("In den ausgewerteten Unterlagen dieser Baustelle finde ich keine übernehmbaren Positionen. Aktuell werden Erschließungs-Unterlagen (Hausanschlüsse) übernommen — weitere Dokumenttypen folgen.")
                    )
                } else {
                    liste
                }
            }
            .navigationTitle("Aus Unterlagen übernehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aufnehmen (\(selektierteAnzahl))") {
                        AuswertungLVMapper.uebernehmen(vorschlaege, in: viewContext, event: event)
                        dismiss()
                    }
                    .tint(.orange)
                    .disabled(selektierteAnzahl == 0)
                }
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                let aus = (EventExtrasPayload.laden(aus: event).auswertungen ?? []).map(\.ergebnis)
                vorschlaege = AuswertungLVMapper.vorschlaege(aus: aus)
            }
        }
    }

    private var liste: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("KI-Vorschläge aus den Unterlagen — prüf jede Menge, bevor du sie aufnimmst. Aufgenommene Positionen landen als geschätzt im LV.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            ForEach(gruppen, id: \.datei) { g in
                Section {
                    ForEach(g.indizes, id: \.self) { i in
                        vorschlagRow($vorschlaege[i])
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.orange)
                        Text(g.datei).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text("\(g.indizes.count) Vorschlag\(g.indizes.count == 1 ? "" : "e")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func vorschlagRow(_ v: Binding<VorschlagLVPosition>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                v.wrappedValue.istSelektiert.toggle()
            } label: {
                Image(systemName: v.wrappedValue.istSelektiert ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(v.wrappedValue.istSelektiert ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(v.wrappedValue.bezeichnung).font(.subheadline)
                HStack(spacing: 6) {
                    Text("KG \(v.wrappedValue.kostenGruppe)")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let h = v.wrappedValue.hinweis {
                        Label(h, systemImage: "info.circle")
                            .font(.caption2).foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
            }
            Spacer(minLength: 6)

            // Menge editierbar — der KI-Wert ist genau der Prüf-Kandidat.
            HStack(spacing: 4) {
                TextField("0", value: v.menge, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                Text(v.wrappedValue.einheit).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
