import SwiftUI
import CoreData

// MARK: - MaterialHinzufuegenView
// Fuegt einer LV-Position ein Material aus den Stammdaten hinzu
// oder erlaubt manuelle Eingabe.

struct MaterialHinzufuegenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let position: LVPosition

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \KalkMaterial.name, ascending: true)]
    ) private var stammdaten: FetchedResults<KalkMaterial>

    @State private var selectedMaterial: KalkMaterial?
    @State private var materialName = ""
    @State private var mengeProEinheit = ""
    @State private var einzelpreis = ""
    @State private var verschnittProzent = "5"
    @State private var einheit = "Stk"
    @State private var manuellMode = false
    @State private var eingabeGesamt = false   // false = Menge je Einheit, true = Gesamt-Materialmenge

    private let einheiten = ["Stk", "m²", "m³", "lfm", "kg", "t", "l"]

    private var isValid: Bool {
        !materialName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(mengeProEinheit.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !manuellMode {
                    stammdatenSection
                }

                if manuellMode || selectedMaterial != nil {
                    detailSection
                }
            }
            .navigationTitle("Material hinzufügen")
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

    // MARK: - Stammdaten-Auswahl

    private var stammdatenSection: some View {
        Section {
            if stammdaten.isEmpty {
                Text("Keine Stammdaten vorhanden")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stammdaten, id: \.objectID) { mat in
                    Button {
                        selectFromStamm(mat)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mat.name ?? "–")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("\(mat.preisProEinheit.formatted(.currency(code: "EUR")))/\(mat.einheit ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedMaterial?.objectID == mat.objectID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            Button {
                manuellMode = true
                selectedMaterial = nil
            } label: {
                Label("Manuell eingeben", systemImage: "pencil")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            Text("Aus Stammdaten wählen")
        }
    }

    // MARK: - Detail-Eingabe

    private var detailSection: some View {
        Section {
            if manuellMode {
                TextField("Materialname", text: $materialName)
                Picker("Einheit", selection: $einheit) {
                    ForEach(einheiten, id: \.self) { Text($0) }
                }
            }

            AufwandEingabeFeld(titel: "Menge",
                               einheit: position.einheit ?? "Einheit",
                               menge: position.menge,
                               text: $mengeProEinheit,
                               gesamt: $eingabeGesamt)

            HStack {
                Text("Einzelpreis")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0,00 €", text: $einzelpreis)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            HStack {
                Text("Verschnitt")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("5", text: $verschnittProzent)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("%")
                    .foregroundStyle(.secondary)
            }

            // Vorschau: Kosten je Einheit UND Positions-Gesamt (macht × Menge sichtbar)
            let vorschau = berechneVorschau()
            if vorschau > 0 {
                let mJe = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
                let gesamtMenge = (mJe * position.menge).formatted(.number.precision(.fractionLength(0...2)))
                AufwandVorschau(proEinheit: vorschau,
                                menge: position.menge,
                                einheit: position.einheit ?? "Einheit",
                                mengenGesamt: "\(gesamtMenge) \(einheit)",   // Material-Einheit (kg/Stk …)
                                farbe: .orange)
            }
        } header: {
            Text("Details")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(eingabeGesamt
                     ? "Gesamt-Materialmenge für die ganze Position (\(mengeText) \(position.einheit ?? "Einheit")) — die App rechnet auf „je Einheit\u{201C} um und speichert das."
                     : "Menge für **eine** \(position.einheit ?? "Einheit") — nicht für die ganze Position. Die Vorschau multipliziert mit der Menge (\(mengeText) \(position.einheit ?? "Einheit")).")
                if let mat = selectedMaterial, mat.verbrauchProM2 > 0 {
                    Text("Richtwert: \(mat.verbrauchProM2.formatted(.number.precision(.fractionLength(0...1)))) \(mat.einheit ?? "") pro m²")
                }
            }
        }
    }

    /// Positions-Menge lesbar (für den Hinweistext).
    private var mengeText: String {
        position.menge.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Actions

    private func selectFromStamm(_ mat: KalkMaterial) {
        selectedMaterial = mat
        manuellMode = false
        eingabeGesamt = false   // Richtwert ist je Einheit → Modus zurücksetzen, sonst falsch interpretiert
        materialName = mat.name ?? ""
        einheit = mat.einheit ?? "Stk"
        einzelpreis = String(format: "%.2f", mat.preisProEinheit).replacingOccurrences(of: ".", with: ",")
        if mat.verbrauchProM2 > 0 {
            mengeProEinheit = String(format: "%.1f", mat.verbrauchProM2).replacingOccurrences(of: ".", with: ",")
        }
        verschnittProzent = String(Int(mat.verschnittProzent * 100))
    }

    private func hinzufuegen() {
        let pm = PositionMaterial(context: viewContext)
        pm.id = UUID()
        pm.materialName = materialName
        pm.einheit = manuellMode ? einheit : (selectedMaterial?.einheit ?? einheit)
        pm.mengeProEinheit = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
        pm.einzelpreis = Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0
        pm.verschnittProzent = (Double(verschnittProzent) ?? 5) / 100.0
        pm.position = position
        try? viewContext.save()
        dismiss()
    }

    private func berechneVorschau() -> Double {
        let menge = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
        let preis = Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0
        let verschnitt = (Double(verschnittProzent) ?? 0) / 100.0
        return menge * preis * (1 + verschnitt)
    }
}
