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
    @State private var eingabeGesamt = false   // false = Stunden je Einheit, true = Gesamt-Stunden
    @State private var pauschal = false         // true = Anzahl × Preis je Einheit (Fuhren/Pauschale)
    @State private var pauschalEinheit = "Fahrt"

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
                Toggle("Pauschal (Fuhren / Pauschale)", isOn: $pauschal).tint(.orange)
                HStack {
                    Text(pauschal ? "€ je \(pauschalEinheit)" : "Kosten/h")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0,00 €", text: $kostenProStunde)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                if pauschal {
                    TextField("Einheit (z.B. Fahrt, Tag)", text: $pauschalEinheit)
                }
            }

            if pauschal {
                HStack {
                    Text("Anzahl (\(pauschalEinheit))").foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", text: $stunden)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
                let anzahl = Double(stunden.replacingOccurrences(of: ",", with: ".")) ?? 0
                let preis = Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) ?? 0
                if anzahl > 0, preis > 0, position.menge > 0 {
                    let gesamt = anzahl * preis
                    Text("\(anzahl.formatted(.number.precision(.fractionLength(0...1)))) \(pauschalEinheit) × \(preis.formatted(.currency(code: "EUR")))/\(pauschalEinheit) = \(gesamt.formatted(.currency(code: "EUR"))) → \((gesamt / position.menge).formatted(.currency(code: "EUR")))/\(position.einheit ?? "Einheit")")
                        .font(.caption).foregroundStyle(.purple).fixedSize(horizontal: false, vertical: true)
                }
            } else {
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
                                    farbe: .purple)
                }
            }
        } header: {
            Text("Einsatz")
        } footer: {
            Text(pauschal
                 ? "Pauschal: Anzahl × Preis je Einheit = Gesamt für die Position (z.B. 6 Fahrten × 120 €) — ehrlich, keine Stunden."
                 : (eingabeGesamt
                    ? "Gesamt-Stunden für die ganze Position (\(mengeText) \(position.einheit ?? "Einheit")) — die App rechnet auf „je Einheit\u{201C} um und speichert das."
                    : "Wert für **eine** \(position.einheit ?? "Einheit") — nicht für die ganze Position. Die Vorschau multipliziert mit der Menge (\(mengeText) \(position.einheit ?? "Einheit"))."))
        }
    }

    /// Positions-Menge lesbar (für den Hinweistext).
    private var mengeText: String {
        position.menge.formatted(.number.precision(.fractionLength(0...2)))
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
        pg.kostenProStunde = Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) ?? 0
        if pauschal {
            // Anzahl absolut (nicht ÷ Menge) — kostenProEinheit teilt selbst durch die Menge.
            pg.stunden = Double(stunden.replacingOccurrences(of: ",", with: ".")) ?? 0
            pg.pauschal = true
            pg.einheit = pauschalEinheit.trimmingCharacters(in: .whitespaces)
        } else {
            pg.stunden = AufwandEingabeFeld.jeEinheit(text: stunden, gesamt: eingabeGesamt, menge: position.menge)
            pg.pauschal = false
            pg.einheit = "h"
        }
        pg.quelle = "eigen"
        pg.position = position
        try? viewContext.save()
        dismiss()
    }

    private func berechneVorschau() -> Double {
        let h = AufwandEingabeFeld.jeEinheit(text: stunden, gesamt: eingabeGesamt, menge: position.menge)
        let kph = Double(kostenProStunde.replacingOccurrences(of: ",", with: ".")) ?? 0
        return h * kph
    }
}
