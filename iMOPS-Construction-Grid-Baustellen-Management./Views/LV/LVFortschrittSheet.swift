import SwiftUI
import CoreData

struct LVFortschrittSheet: View {
    @Environment(\.dismiss) private var dismiss
    let position: LVPosition
    @StateObject private var store = LVFortschrittStore.shared

    @State private var prozent: Double
    @State private var bemerkung: String

    init(position: LVPosition) {
        self.position = position
        let id = position.objectID.uriRepresentation().absoluteString
        let existing = LVFortschrittStore.shared.fortschritt(for: id)
        _prozent = State(initialValue: Double(existing?.prozent ?? 0))
        _bemerkung = State(initialValue: existing?.bemerkung ?? "")
    }

    private var farbe: Color {
        Int(prozent) == 100 ? .green : Int(prozent) > 0 ? .orange : .secondary
    }

    var body: some View {
        NavigationStack {
            Form {
                if position.hatAufmass, let g = position.gemessenerFortschrittProzent {
                    Section {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "ruler").foregroundStyle(.blue).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Aufmaß übersteuert deine Schätzung.")
                                    .font(.callout.weight(.medium))
                                Text("Angezeigt wird die Messung: \(Int(g.rounded())) %. Deine Einschätzung (\(Int(prozent)) %) bleibt gespeichert.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            PhilosophieTooltip(
                                buchKapitel: "Buch Kap 9",
                                text: "Sag dir, warum dein Schieber den Balken nicht bewegt — statt dich rätseln zu lassen."
                            )
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(position.bezeichnung ?? "–")
                            .font(.body).lineLimit(3)
                        HStack {
                            Text(position.posNr ?? "").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(prozent)) %")
                                .font(.title.weight(.bold).monospacedDigit())
                                .foregroundStyle(farbe)
                        }
                        ProgressView(value: prozent, total: 100)
                            .progressViewStyle(.linear)
                            .tint(farbe)
                        Slider(value: $prozent, in: 0...100, step: 5)
                            .tint(farbe)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 6) {
                        ForEach([0, 25, 50, 75, 100], id: \.self) { v in
                            Button { prozent = Double(v) } label: {
                                Text("\(v) %")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(Int(prozent) == v ? farbe : Color(.tertiarySystemFill))
                                    .foregroundStyle(Int(prozent) == v ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("Fertigstellungsgrad") }

                Section("Bemerkung (optional)") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Status-Notiz...", text: $bemerkung, axis: .vertical)
                            .lineLimit(2...4)
                        VoiceInputButton(text: $bemerkung).padding(.top, 2)
                    }
                }
            }
            .navigationTitle("Fortschritt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.tint(.orange)
                }
            }
        }
    }

    private func save() {
        let id = position.objectID.uriRepresentation().absoluteString
        if Int(prozent) == 0 {
            store.remove(for: id)
        } else {
            store.setFortschritt(
                LVFortschritt(prozent: Int(prozent), bemerkung: bemerkung), for: id)
        }
        dismiss()
    }
}
