import SwiftUI
import CoreData

// MARK: - MopsVorschlagSheet
// Sheet fuer den optionalen Mops/Prof-Vorschlag bei der Kalkulation.
// Fragt nach Aufwandswerten oder Material-Alternativen.
// IMMER nur Vorschlag — User entscheidet.

struct MopsVorschlagSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var position: LVPosition
    @Binding var antwort: String?

    @State private var isLoading = false
    @State private var mopsText: String?
    @State private var errorText: String?
    @State private var selectedAction = 0
    @State private var showApplyConfirmation = false
    @State private var didApplyText = false

    private let aktionen = ["Aufwandswert", "Material-Alternative", "Positionstext"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Text("🐶")
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mops fragen")
                            .font(.headline)
                        Text("Vorschlag — du entscheidest!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Aktion waehlen
                Picker("Aktion", selection: $selectedAction) {
                    ForEach(0..<aktionen.count, id: \.self) { i in
                        Text(aktionen[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Position-Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.bezeichnung ?? "Unbenannte Position")
                        .font(.subheadline)
                        .bold()
                    Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

                // Ergebnis
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Mops denkt nach …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 30)
                }

                if let text = mopsText {
                    ScrollView {
                        Text(text)
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(10)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal)

                    if selectedAction == 2 {
                        Button {
                            showApplyConfirmation = true
                        } label: {
                            Label(
                                didApplyText ? "Positionstext übernommen" : "Positionstext übernehmen",
                                systemImage: didApplyText ? "checkmark.circle.fill" : "text.badge.checkmark"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(didApplyText ? .green : .orange)
                        .padding(.horizontal)
                        .disabled(didApplyText)
                    }
                }

                if let err = errorText {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Schließen")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        fragenAbschicken()
                    } label: {
                        Label("Fragen", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("Mops-Vorschlag")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Positionstext übernehmen?", isPresented: $showApplyConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Übernehmen", role: .destructive) {
                    positionstextUebernehmen()
                }
            } message: {
                Text("Der bestehende Positionstext wird ersetzt. Bitte nur übernehmen, wenn du den Vorschlag fachlich geprüft hast.")
            }
        }
    }

    // MARK: - Mops fragen

    private func fragenAbschicken() {
        isLoading = true
        errorText = nil
        mopsText = nil

        let helper = MopsKalkulationsHelper.shared
        let leistung = "\(position.menge.formatted()) \(position.einheit ?? "") \(position.bezeichnung ?? "")"
        didApplyText = false

        Task {
            switch selectedAction {
            case 0:
                // Aufwandswert
                if let wert = await helper.aufwandswertVorschlag(leistung: leistung) {
                    await MainActor.run {
                        let text = "Vorschlag (REFA):\n• Maurer: \(wert.maurer) h/\(position.einheit ?? "E")\n• Helfer: \(wert.helfer) h/\(position.einheit ?? "E")"
                        mopsText = text
                        antwort = text
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorText = "Keine Antwort erhalten. Mops offline?"
                        isLoading = false
                    }
                }

            case 1:
                // Material-Alternative
                let material = position.materialArray.first?.materialName ?? position.bezeichnung ?? ""
                if let alt = await helper.materialAlternative(material: material, anforderung: leistung) {
                    await MainActor.run {
                        mopsText = alt
                        antwort = alt
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorText = "Keine Antwort erhalten."
                        isLoading = false
                    }
                }

            case 2:
                // Positionstext
                if let text = await helper.positionstextGenerieren(leistung: position.bezeichnung ?? "", details: leistung) {
                    await MainActor.run {
                        mopsText = text
                        antwort = text
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        errorText = "Keine Antwort erhalten."
                        isLoading = false
                    }
                }

            default:
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func positionstextUebernehmen() {
        guard let text = mopsText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return
        }

        position.bezeichnung = text
        try? viewContext.save()
        antwort = text
        didApplyText = true
    }
}
