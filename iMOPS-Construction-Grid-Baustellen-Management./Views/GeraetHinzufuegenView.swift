import SwiftUI
import CoreData

// MARK: - GeraetHinzufuegenView
// Fuegt einer LV-Position Geraetekosten hinzu.
// Waehlt aus Stamm-Geraeten oder erlaubt manuelle Eingabe.

struct GeraetHinzufuegenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let position: LVPosition

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Geraet.name, ascending: true)]
    ) private var geraete: FetchedResults<Geraet>

    @State private var selectedGeraet: Geraet?
    @State private var geraetName = ""
    @State private var stunden = ""
    @State private var kostenProStunde = ""
    @State private var manuellMode = false

    private var isValid: Bool {
        !geraetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(stunden.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !manuellMode {
                    stammdatenSection
                }

                if manuellMode || selectedGeraet != nil {
                    detailSection
                }
            }
            .navigationTitle("Gerät hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { hinzufuegen() }
                        .disabled(!isValid)
                        .tint(.orange)
                }
            }
        }
    }

    // MARK: - Stammdaten

    private var stammdatenSection: some View {
        Section {
            if geraete.isEmpty {
                Text("Keine Geräte hinterlegt")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(geraete, id: \.objectID) { g in
                    Button {
                        selectFromStamm(g)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name ?? "–")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("\(g.kostenProStunde.formatted(.currency(code: "EUR")))/h")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedGeraet?.objectID == g.objectID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            Button {
                manuellMode = true
                selectedGeraet = nil
            } label: {
                Label("Manuell eingeben", systemImage: "pencil")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            Text("Gerät wählen")
        }
    }

    // MARK: - Details

    private var detailSection: some View {
        Section {
            if manuellMode {
                TextField("Gerätename", text: $geraetName)
                HStack {
                    Text("Kosten/h")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0,00 €", text: $kostenProStunde)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            HStack {
                Text("Stunden/\(position.einheit ?? "Einheit")")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0,00", text: $stunden)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            // Vorschau
            let vorschau = berechneVorschau()
            if vorschau > 0 {
                HStack {
                    Text("Kosten/\(position.einheit ?? "Einheit")")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(vorschau.formatted(.currency(code: "EUR")))
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.purple)
                }
            }
        } header: {
            Text("Einsatz")
        }
    }

    // MARK: - Actions

    private func selectFromStamm(_ g: Geraet) {
        selectedGeraet = g
        manuellMode = false
        geraetName = g.name ?? ""
        kostenProStunde = String(format: "%.2f", g.kostenProStunde).replacingOccurrences(of: ".", with: ",")
    }

    private func hinzufuegen() {
        let pg = PositionGeraet(context: viewContext)
        pg.id = UUID()
        pg.geraetName = geraetName
        pg.stunden = Double(stunden.replacingOccurrences(of: ",", with: ".")) ?? 0
        pg.kostenProStunde = Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) ?? 0
        pg.position = position
        try? viewContext.save()
        dismiss()
    }

    private func berechneVorschau() -> Double {
        let h = Double(stunden.replacingOccurrences(of: ",", with: ".")) ?? 0
        let kph = Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) ?? 0
        return h * kph
    }
}
