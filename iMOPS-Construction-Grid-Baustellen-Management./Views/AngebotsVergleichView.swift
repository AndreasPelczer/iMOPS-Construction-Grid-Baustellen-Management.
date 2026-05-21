import SwiftUI
import CoreData

// MARK: - Angebotsvergleich

struct AngebotsVergleichView: View {
    let event: Event
    let positionen: [LVPosition]

    @StateObject private var store = AngebotsStore.shared
    @State private var editTarget: LVPosition?
    @State private var editAngebot: Angebot?
    @Environment(\.dismiss) private var dismiss

    private let bekannteAnbieter = ["Scharpegge", "Hauff", "Baumarkt", "Sonstige"]

    // Alle Lieferanten die überhaupt Angebote haben
    private var aktiveAnbieter: [String] {
        var set = Set<String>()
        for pos in positionen {
            let id = pos.objectID.uriRepresentation().absoluteString
            store.angebote(for: id).forEach { set.insert($0.lieferant) }
        }
        let sorted = bekannteAnbieter.filter { set.contains($0) }
        let rest = set.subtracting(bekannteAnbieter).sorted()
        return sorted + rest
    }

    // GP-Summe pro Lieferant über alle Positionen
    private func gesamtGP(lieferant: String) -> Double {
        positionen.reduce(0) { sum, pos in
            let id = pos.objectID.uriRepresentation().absoluteString
            guard let ang = store.data[id]?[lieferant] else { return sum }
            return sum + ang.einzelpreis * pos.menge
        }
    }

    private var guenstigsterAnbieter: String? {
        aktiveAnbieter.min { gesamtGP(lieferant: $0) < gesamtGP(lieferant: $1) }
    }

    var body: some View {
        NavigationStack {
            List {
                if positionen.isEmpty {
                    ContentUnavailableView(
                        "Keine Positionen",
                        systemImage: "doc.text",
                        description: Text("Zuerst LV-Positionen anlegen.")
                    )
                } else {
                    if !aktiveAnbieter.isEmpty {
                        gesamtSection
                    }
                    positionenSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Angebotsvergleich")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
            .sheet(item: $editTarget) { pos in
                AngebotEingabeView(
                    position: pos,
                    initialAngebot: editAngebot,
                    onSave: { angebot in
                        let id = pos.objectID.uriRepresentation().absoluteString
                        store.upsert(angebot, for: id)
                    }
                )
            }
        }
    }

    // MARK: - Gesamt-Sektion

    private var gesamtSection: some View {
        Section {
            ForEach(aktiveAnbieter, id: \.self) { anbieter in
                let gp = gesamtGP(lieferant: anbieter)
                let isBest = anbieter == guenstigsterAnbieter
                HStack {
                    if isBest {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                    Text(anbieter)
                        .font(.body.weight(isBest ? .semibold : .regular))
                        .foregroundStyle(isBest ? .green : .primary)
                    Spacer()
                    Text(gp, format: .currency(code: "EUR"))
                        .font(.body.monospacedDigit().weight(isBest ? .semibold : .regular))
                        .foregroundStyle(isBest ? .green : .primary)
                }
            }
        } header: {
            Text("Gesamt GP pro Lieferant")
        } footer: {
            if let best = guenstigsterAnbieter {
                Text("Günstigster Anbieter: \(best)")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Positionen-Sektion

    private var positionenSection: some View {
        Section("Positionen") {
            ForEach(positionen, id: \.objectID) { pos in
                positionRow(pos)
            }
        }
    }

    @ViewBuilder
    private func positionRow(_ pos: LVPosition) -> some View {
        let id = pos.objectID.uriRepresentation().absoluteString
        let angebote = store.angebote(for: id)
        let bestes = store.guenstigster(for: id)

        VStack(alignment: .leading, spacing: 8) {
            // Position Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pos.bezeichnung ?? "–").font(.subheadline.weight(.medium)).lineLimit(2)
                    Text("\(pos.menge.formatted(.number.precision(.fractionLength(0...2)))) \(pos.einheit ?? "") · KG \(pos.kostenGruppeNummer ?? "–")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editAngebot = nil
                    editTarget  = pos
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.orange)
                }
            }

            // Angebotszeilen
            if angebote.isEmpty {
                Text("Noch kein Angebot erfasst")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(angebote, id: \.lieferant) { ang in
                        let gp = ang.einzelpreis * pos.menge
                        let isBest = ang.lieferant == bestes?.lieferant
                        HStack {
                            if isBest {
                                Image(systemName: "star.fill")
                                    .font(.caption2).foregroundStyle(.orange)
                            } else {
                                Image(systemName: "star")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(ang.lieferant)
                                .font(.caption.weight(isBest ? .semibold : .regular))
                                .foregroundStyle(isBest ? .orange : .secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(ang.einzelpreis, format: .currency(code: "EUR"))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text("GP: \(gp.formatted(.currency(code: "EUR")))")
                                    .font(.caption.monospacedDigit().weight(isBest ? .semibold : .regular))
                                    .foregroundStyle(isBest ? .orange : .primary)
                            }
                            Button {
                                editAngebot = ang
                                editTarget  = pos
                            } label: {
                                Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.leading, 6)
                            Button {
                                store.remove(lieferant: ang.lieferant, for: id)
                            } label: {
                                Image(systemName: "trash").font(.caption).foregroundStyle(.red.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(isBest ? Color.orange.opacity(0.07) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Angebot Eingabe Sheet

struct AngebotEingabeView: View {
    let position: LVPosition
    let initialAngebot: Angebot?
    let onSave: (Angebot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lieferant = "Scharpegge"
    @State private var einzelpreis = ""
    @State private var notiz = ""

    private let lieferanten = ["Scharpegge", "Hauff", "Baumarkt", "Sonstige"]

    private var isValid: Bool {
        Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var epDouble: Double {
        Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var gpPreview: Double { epDouble * position.menge }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    Text(position.bezeichnung ?? "–").foregroundStyle(.secondary)
                    Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Angebot") {
                    Picker("Lieferant", selection: $lieferant) {
                        ForEach(lieferanten, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Text("EP (€)").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0,00", text: $einzelpreis)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    if isValid && epDouble > 0 {
                        HStack {
                            Text("GP (€)").foregroundStyle(.secondary)
                            Spacer()
                            Text(gpPreview, format: .currency(code: "EUR"))
                                .foregroundStyle(.orange)
                                .font(.body.monospacedDigit())
                        }
                    }
                }
                Section("Notiz (optional)") {
                    TextField("z.B. Gültig bis 31.12., Lieferzeit 2 Wochen", text: $notiz, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(initialAngebot == nil ? "Angebot erfassen" : "Angebot bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        onSave(Angebot(
                            lieferant: lieferant,
                            einzelpreis: epDouble,
                            notiz: notiz
                        ))
                        dismiss()
                    }
                    .disabled(!isValid || epDouble == 0)
                    .tint(.orange)
                }
            }
            .onAppear {
                if let a = initialAngebot {
                    lieferant    = a.lieferant
                    einzelpreis  = String(format: "%.2f", a.einzelpreis).replacingOccurrences(of: ".", with: ",")
                    notiz        = a.notiz
                }
            }
        }
    }
}
