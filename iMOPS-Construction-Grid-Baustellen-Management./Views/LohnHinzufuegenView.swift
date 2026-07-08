import SwiftUI
import CoreData

// MARK: - LohnHinzufuegenView
// Fuegt einer LV-Position einen Lohnanteil hinzu.
// Waehlt aus Stamm-Lohnsaetzen oder erlaubt manuelle Eingabe.

struct LohnHinzufuegenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let position: LVPosition

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Lohnsatz.qualifikation, ascending: true)]
    ) private var lohnsaetze: FetchedResults<Lohnsatz>

    @State private var selectedLohnsatz: Lohnsatz?
    @State private var qualifikation = ""
    @State private var stunden = ""
    @State private var stundenBruttoEK = ""
    @State private var manuellMode = false
    @State private var eingabeGesamt = false   // false = Stunden je Einheit, true = Gesamt-Stunden

    private var isValid: Bool {
        !qualifikation.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(stunden.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(stundenBruttoEK.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if !manuellMode {
                    stammdatenSection
                }

                if manuellMode || selectedLohnsatz != nil {
                    detailSection
                }
            }
            .navigationTitle("Lohnanteil hinzufügen")
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
            if lohnsaetze.isEmpty {
                Text("Keine Lohnsätze hinterlegt")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lohnsaetze, id: \.objectID) { ls in
                    Button {
                        selectFromStamm(ls)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ls.qualifikation ?? "–")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("\(ls.stundenlohn.formatted(.currency(code: "EUR")))/h × \(ls.zuschlagFaktor.formatted(.number.precision(.fractionLength(2)))) = \(ls.berechnungBruttoEK.formatted(.currency(code: "EUR")))/h brutto")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedLohnsatz?.objectID == ls.objectID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            Button {
                manuellMode = true
                selectedLohnsatz = nil
            } label: {
                Label("Manuell eingeben", systemImage: "pencil")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            Text("Qualifikation wählen")
        }
    }

    // MARK: - Details

    private var detailSection: some View {
        Section {
            if manuellMode {
                TextField("Qualifikation", text: $qualifikation)
                HStack {
                    Text("Brutto-EK/h")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0,00 €", text: $stundenBruttoEK)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            AufwandEingabeFeld(titel: "Stunden",
                               einheit: position.einheit ?? "Einheit",
                               menge: position.menge,
                               text: $stunden,
                               gesamt: $eingabeGesamt)

            // Vorschau: Kosten je Einheit UND Positions-Gesamt (macht × Menge sichtbar)
            let vorschau = berechneVorschau()
            if vorschau > 0 {
                let hJe = AufwandEingabeFeld.jeEinheit(text: stunden, gesamt: eingabeGesamt, menge: position.menge)
                let gesamtStunden = (hJe * position.menge).formatted(.number.precision(.fractionLength(0...2)))
                AufwandVorschau(proEinheit: vorschau,
                                menge: position.menge,
                                einheit: position.einheit ?? "Einheit",
                                mengenGesamt: "\(gesamtStunden) h",
                                farbe: .green)
            }
        } header: {
            Text("Aufwand")
        } footer: {
            Text(eingabeGesamt
                 ? "Gesamt-Stunden für die ganze Position (\(mengeText) \(position.einheit ?? "Einheit")) — die App rechnet auf „je Einheit\u{201C} um und speichert das."
                 : "Wert für **eine** \(position.einheit ?? "Einheit") — nicht für die ganze Position. Die Vorschau multipliziert mit der Menge (\(mengeText) \(position.einheit ?? "Einheit")).")
        }
    }

    /// Positions-Menge lesbar (für den Hinweistext).
    private var mengeText: String {
        position.menge.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Actions

    private func selectFromStamm(_ ls: Lohnsatz) {
        selectedLohnsatz = ls
        manuellMode = false
        qualifikation = ls.qualifikation ?? ""
        stundenBruttoEK = String(format: "%.2f", ls.berechnungBruttoEK).replacingOccurrences(of: ".", with: ",")
    }

    private func hinzufuegen() {
        let pl = PositionLohn(context: viewContext)
        pl.id = UUID()
        pl.qualifikation = qualifikation
        pl.stunden = AufwandEingabeFeld.jeEinheit(text: stunden, gesamt: eingabeGesamt, menge: position.menge)
        pl.stundenBruttoEK = Double(stundenBruttoEK.replacingOccurrences(of: ",", with: ".")) ?? 0
        pl.position = position
        try? viewContext.save()
        dismiss()
    }

    private func berechneVorschau() -> Double {
        let h = AufwandEingabeFeld.jeEinheit(text: stunden, gesamt: eingabeGesamt, menge: position.menge)
        let brutto = Double(stundenBruttoEK.replacingOccurrences(of: ",", with: ".")) ?? 0
        return h * brutto
    }
}
