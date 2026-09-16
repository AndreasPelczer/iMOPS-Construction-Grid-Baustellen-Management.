import SwiftUI
import UniformTypeIdentifiers
import CoreData

// MARK: - MopsFassReviewView
//
// Zeigt das Ergebnis von „Mops fass" als Ampel-Review:
//   🔴 ROT   — kein Rezept, braucht manuelle Kalkulation / Katalog / Stammdaten
//   🟡 GELB  — Rezept da, aber ein Wert fehlt (Aufwandswert/Material) → prüfen
//   🟢 GRÜN  — automatisch kalkuliert, mit transparenter Quelle
//
// Sortierung: ROT zuerst (das drängt). Export (X84) ist gesperrt, solange eine
// Position ROT ist — das Vier-Augen-Prinzip bleibt beim Menschen.
struct MopsFassReviewView: View {

    let ergebnisse: [AutoKalkulationsService.Ergebnis]
    let event: Event
    var onFertig: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var zeigeExport = false
    @State private var exportDoc: GAEBTextDocument?

    private var bilanz: AutoKalkulationsService.Bilanz { AutoKalkulationsService.bilanz(ergebnisse) }

    private var sortiert: [AutoKalkulationsService.Ergebnis] {
        let rang: [AutoKalkulationsService.Status: Int] = [.rot: 0, .gelb: 1, .gruen: 2]
        return ergebnisse.sorted { (rang[$0.status] ?? 3) < (rang[$1.status] ?? 3) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 20) {
                        ampel("🟢", bilanz.gruen, "kalkuliert")
                        ampel("🟡", bilanz.gelb, "prüfen")
                        ampel("🔴", bilanz.rot, "fehlt")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    if bilanz.rot > 0 {
                        Text("Export gesperrt, solange rote Positionen offen sind.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Mops fass — \(bilanz.gesamt) Positionen")
                }

                ForEach(sortiert) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(dot(e.status))
                            Text(e.position.posNr ?? "")
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                            Text(e.position.bezeichnung ?? "")
                                .font(.subheadline).lineLimit(2)
                            Spacer(minLength: 8)
                            if e.einheitspreisVK > 0 {
                                Text(e.einheitspreisVK, format: .currency(code: "EUR"))
                                    .font(.caption.monospaced())
                            } else {
                                Text("—").foregroundStyle(.secondary)
                            }
                        }
                        ForEach(e.meldungen, id: \.self) { m in
                            Text(m).font(.caption2).foregroundStyle(farbe(e.status))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Kalkulations-Review")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { onFertig(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("X84 exportieren") { starteExport() }
                        .disabled(!bilanz.exportBereit)
                }
            }
            .fileExporter(isPresented: $zeigeExport, document: exportDoc,
                          contentType: .xml,
                          defaultFilename: "Angebot_\(event.eventNumber ?? "LV")_X84") { _ in }
        }
    }

    private func starteExport() {
        let positionen = ergebnisse.map { $0.position }
        let data = GAEBExporter.export(event: event, positionen: positionen, format: .x84_v33)
        exportDoc = GAEBTextDocument(data: data)
        zeigeExport = true
    }

    private func ampel(_ icon: String, _ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.title2)
            Text("\(n)").font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func dot(_ s: AutoKalkulationsService.Status) -> String {
        switch s { case .gruen: return "🟢"; case .gelb: return "🟡"; case .rot: return "🔴" }
    }
    private func farbe(_ s: AutoKalkulationsService.Status) -> Color {
        switch s { case .gruen: return .green; case .gelb: return .orange; case .rot: return .red }
    }
}

// Minimaler FileDocument-Wrapper für den GAEB-Export (X84 XML).
struct GAEBTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
