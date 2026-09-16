import SwiftUI
import CoreData

// MARK: - MopsVorschlagSheet
// Der Mops/Prof-Vorschlag für den Aufwandswert (die einzige Frage, die echte Zahlen liefert:
// Maurer/Helfer h je Einheit, geparst und ins Rezept übernehmbar). Material-Alternative und
// Positionstext-Generierung sind rausgeflogen — sie lieferten nur generischen KI-Rohtext.
// IMMER nur Vorschlag (Schätzung) — der User entscheidet.

struct MopsVorschlagSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var position: LVPosition
    @Binding var antwort: String?

    @State private var isLoading = false
    @State private var errorText: String?
    @State private var aufwandVorschlag: (maurer: Double, helfer: Double)?
    @State private var aufwandUebernommen = false
    @State private var showAufwandConfirmation = false

    private var einheit: String { position.einheit ?? "E" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                header
                positionInfo
                if let err = errorText {
                    Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
                ScrollView {
                    VStack(spacing: 14) { aufwandCard }.padding(.horizontal)
                }
                aktionsButtons
            }
            .padding(.top)
            .navigationTitle("Mops-Vorschlag")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("Aufwandswert als Schätzung übernehmen?", isPresented: $showAufwandConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Übernehmen") { aufwandUebernehmen() }
            } message: {
                Text("Der Vorschlag (REFA) ist eine Schätzung, kein fester Wert. Er wird auf die Position geschrieben und für die nächste gleiche Leistung gemerkt — bitte fachlich prüfen und bei Bedarf anpassen.")
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        HStack(spacing: 12) {
            Text("🐶").font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text("Mops fragen").font(.headline)
                Text("Aufwandswert-Vorschlag — du entscheidest!").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var positionInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(position.bezeichnung ?? "Unbenannte Position").font(.subheadline).bold()
            Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var aufwandCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⏱ Aufwandswert (REFA)").font(.subheadline.weight(.semibold))
            if let w = aufwandVorschlag {
                Text("• Maurer: \(fmt(w.maurer)) h/\(einheit)   →  gesamt \(fmt(w.maurer * position.menge)) h\n• Helfer: \(fmt(w.helfer)) h/\(einheit)   →  gesamt \(fmt(w.helfer * position.menge)) h")
                    .font(.subheadline)
                Text("Zusammen ≈ \(fmt((w.maurer + w.helfer) * position.menge)) Std für \(fmt(position.menge)) \(position.einheit ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    showAufwandConfirmation = true
                } label: {
                    Label(aufwandUebernommen ? "Als Schätzung übernommen" : "Übernehmen (Schätzung)",
                          systemImage: aufwandUebernommen ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(aufwandUebernommen ? .green : .orange)
                .disabled(aufwandUebernommen)
            } else {
                HStack(spacing: 8) {
                    if isLoading { ProgressView() }
                    Text(isLoading ? "Mops denkt nach …" : "— auf „Aufwandswert fragen“ tippen")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.06))
        .cornerRadius(10)
    }

    private var aktionsButtons: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: { Text("Schließen").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
            Button { fragenAbschicken() } label: {
                Label("Aufwandswert fragen", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(.orange).disabled(isLoading)
        }
        .padding(.horizontal).padding(.bottom)
    }

    // MARK: - Logik

    private func fragenAbschicken() {
        isLoading = true; errorText = nil
        aufwandVorschlag = nil; aufwandUebernommen = false
        let helper = MopsKalkulationsHelper.shared
        let leistung = "\(position.menge.formatted()) \(position.einheit ?? "") \(position.bezeichnung ?? "")"
        Task {
            let a = await helper.aufwandswertVorschlag(leistung: leistung)
            await MainActor.run {
                aufwandVorschlag = a
                if let a { antwort = "Aufwand: Maurer \(fmt(a.maurer)) / Helfer \(fmt(a.helfer)) h/\(einheit)" }
                else { errorText = "Keine Antwort erhalten. Mops offline?" }
                isLoading = false
            }
        }
    }

    /// Aufwandswert übernehmen: auf die Position schreiben UND ins Rezept lernen (Herkunft „schätzung").
    private func aufwandUebernehmen() {
        guard let w = aufwandVorschlag else { return }
        LeistungskatalogService.uebernehmeAufwand(
            maurer: w.maurer, helfer: w.helfer, quelle: "schätzung",
            auf: position, in: viewContext)
        try? viewContext.save()
        aufwandUebernommen = true
    }

    private func fmt(_ d: Double) -> String { String(format: "%g", d) }
}
