import CoreData
import SwiftUI

struct LVBausteinAuswahlView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @State private var selectedTitelID = LVBausteinKatalog.titel.first?.id ?? ""
    @State private var selectedPositionIDs: Set<String> = []

    private var selectedTitel: LVBausteinTitel? {
        LVBausteinKatalog.titel.first { $0.id == selectedTitelID }
    }

    private var vorhandenePosNr: Set<String> {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        return Set(positionen.compactMap { $0.posNr })
    }

    private var auswahl: [LVBausteinPosition] {
        selectedTitel?.positionen.filter { selectedPositionIDs.contains($0.id) } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Titel", selection: $selectedTitelID) {
                        ForEach(LVBausteinKatalog.titel) { titel in
                            Text(titel.anzeige).tag(titel.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedTitelID) { _, _ in
                        selectedPositionIDs.removeAll()
                    }
                } footer: {
                    Text("Bausteine sind Vorlagen. Mengen, Preise und KG bitte nach dem Übernehmen prüfen.")
                }

                if let titel = selectedTitel {
                    Section(titel.anzeige) {
                        ForEach(titel.positionen) { baustein in
                            Button {
                                toggle(baustein)
                            } label: {
                                bausteinRow(baustein)
                            }
                            .buttonStyle(.plain)
                            .disabled(vorhandenePosNr.contains(baustein.posNr))
                        }
                    }
                }
            }
            .navigationTitle("LV-Bausteine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { uebernehmen() }
                        .disabled(auswahl.isEmpty)
                        .tint(.orange)
                }
            }
        }
    }

    private func bausteinRow(_ baustein: LVBausteinPosition) -> some View {
        let istVorhanden = vorhandenePosNr.contains(baustein.posNr)
        let istAusgewaehlt = selectedPositionIDs.contains(baustein.id)
        let markerColor: Color = istVorhanden ? .secondary : (istAusgewaehlt ? .orange : .secondary)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: istVorhanden ? "checkmark.seal.fill" : (istAusgewaehlt ? "checkmark.circle.fill" : "circle"))
                .foregroundStyle(markerColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(baustein.posNr)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Text(baustein.bezeichnung)
                        .foregroundStyle(istVorhanden ? .secondary : .primary)
                }

                HStack(spacing: 8) {
                    Text("\(baustein.menge.formatted(.number.precision(.fractionLength(0...3)))) \(baustein.einheit)")
                    Text("EP \(baustein.einzelPreis.formatted(.currency(code: "EUR")))")
                    Text("KG \(baustein.kostenGruppeNummer)")
                    if istVorhanden {
                        Text("bereits im LV")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func toggle(_ baustein: LVBausteinPosition) {
        guard !vorhandenePosNr.contains(baustein.posNr) else { return }
        if selectedPositionIDs.contains(baustein.id) {
            selectedPositionIDs.remove(baustein.id)
        } else {
            selectedPositionIDs.insert(baustein.id)
        }
    }

    private func uebernehmen() {
        for baustein in auswahl where !vorhandenePosNr.contains(baustein.posNr) {
            let pos = LVPosition(context: viewContext)
            pos.posNr = baustein.posNr
            pos.bezeichnung = baustein.bezeichnung
            pos.menge = baustein.menge
            pos.einheit = baustein.einheit
            pos.kostenGruppeNummer = baustein.kostenGruppeNummer
            pos.mengenQuelleRaw = "manuell"
            pos.quellDatei = "LV-Bausteinkatalog"
            pos.setValue(baustein.einzelPreis, forKey: "einkaufspreis")
            pos.event = event
        }

        try? viewContext.save()
        dismiss()
    }
}
