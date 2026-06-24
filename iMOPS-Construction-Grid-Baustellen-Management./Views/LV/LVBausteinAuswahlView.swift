import CoreData
import SwiftUI

struct LVBausteinAuswahlView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @State private var selectedTitelID = LVBausteinKatalog.titel.first?.id ?? ""
    @State private var selectedPositionIDs: Set<String> = []
    @State private var eigenePosNr = ""
    @State private var eigeneBezeichnung = ""
    @State private var eigeneMenge = "1,00"
    @State private var eigeneEinheit = "Pau"
    @State private var eigenerEinzelPreis = "0,00"
    @State private var eigeneKG = "390"

    private let einheiten = ["Pau", "Psch", "Wo", "m", "m²", "m³", "m*W", "Stück", "kg", "t", "h"]

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

    private var eigenePositionIstGueltig: Bool {
        let nr = eigenePosNr.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = eigeneBezeichnung.trimmingCharacters(in: .whitespacesAndNewlines)
        return !nr.isEmpty &&
            !text.isEmpty &&
            !vorhandenePosNr.contains(nr) &&
            parseDecimal(eigeneMenge) != nil &&
            parseDecimal(eigenerEinzelPreis) != nil
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
                        eigenePosNr = naechstePositionsnummer()
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

                Section {
                    HStack {
                        Text("Pos.-Nr.").foregroundStyle(.secondary).frame(width: 88, alignment: .leading)
                        TextField("01.0050", text: $eigenePosNr)
                            .keyboardType(.numbersAndPunctuation)
                            .monospacedDigit()
                    }

                    TextField("Bezeichnung", text: $eigeneBezeichnung, axis: .vertical)
                        .lineLimit(2...4)

                    HStack {
                        TextField("Menge", text: $eigeneMenge)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 120)
                        Picker("Einheit", selection: $eigeneEinheit) {
                            ForEach(einheiten, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("EP").foregroundStyle(.secondary).frame(width: 88, alignment: .leading)
                        TextField("0,00", text: $eigenerEinzelPreis)
                            .keyboardType(.decimalPad)
                    }

                    NavigationLink { KGPickerList(selected: $eigeneKG) } label: {
                        HStack {
                            Text("KG")
                            Spacer()
                            Text(eigeneKG).foregroundStyle(.orange)
                        }
                    }

                    Button {
                        eigenePositionUebernehmen()
                    } label: {
                        Label("Eigene Position übernehmen", systemImage: "plus.circle.fill")
                    }
                    .disabled(!eigenePositionIstGueltig)
                } header: {
                    Text("Eigene Position")
                } footer: {
                    if vorhandenePosNr.contains(eigenePosNr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Text("Diese Positionsnummer ist bereits im LV vorhanden.")
                    } else {
                        Text("Eigene Positionen werden direkt ins LV geschrieben und als manuelle Quelle markiert.")
                    }
                }
            }
            .navigationTitle("LV-Bausteine")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if eigenePosNr.isEmpty {
                    eigenePosNr = naechstePositionsnummer()
                }
            }
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

    private func eigenePositionUebernehmen() {
        guard
            eigenePositionIstGueltig,
            let menge = parseDecimal(eigeneMenge),
            let ep = parseDecimal(eigenerEinzelPreis)
        else { return }

        let pos = LVPosition(context: viewContext)
        pos.posNr = eigenePosNr.trimmingCharacters(in: .whitespacesAndNewlines)
        pos.bezeichnung = eigeneBezeichnung.trimmingCharacters(in: .whitespacesAndNewlines)
        pos.menge = menge
        pos.einheit = eigeneEinheit
        pos.kostenGruppeNummer = eigeneKG
        pos.mengenQuelleRaw = "manuell"
        pos.quellDatei = "Eigene LV-Position"
        pos.setValue(ep, forKey: "einkaufspreis")
        pos.event = event

        try? viewContext.save()
        dismiss()
    }

    private func parseDecimal(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func naechstePositionsnummer() -> String {
        let titel = selectedTitelID.isEmpty ? "01" : selectedTitelID
        let prefix = "\(titel)."
        let katalogNummern = selectedTitel?.positionen.map(\.posNr) ?? []
        let eventNummern = ((event.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .compactMap(\.posNr)
            .filter { $0.hasPrefix(prefix) }

        let maxSuffix = (katalogNummern + eventNummern)
            .compactMap { nummer -> Int? in
                guard let suffix = nummer.split(separator: ".").last else { return nil }
                return Int(suffix)
            }
            .max() ?? 0

        let next = ((maxSuffix / 10) + 1) * 10
        return "\(titel).\(String(format: "%04d", next))"
    }
}
