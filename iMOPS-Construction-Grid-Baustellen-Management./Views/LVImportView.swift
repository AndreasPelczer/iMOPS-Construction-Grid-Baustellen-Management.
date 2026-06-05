import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - LV Import View

struct LVImportView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDocumentPicker = false
    @State private var parsedPositions: [ParsedLVPosition] = []
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var showError = false
    @State private var importQuelle: ImportQuelle = .lokal
    @State private var parsingHinweis = "PDF wird analysiert ..."

    private enum ImportQuelle { case lokal, mops }

    private var selectedCount: Int { parsedPositions.filter { $0.isSelected }.count }
    private var allSelected: Bool  { parsedPositions.allSatisfy { $0.isSelected } }

    var body: some View {
        NavigationStack {
            Group {
                if parsedPositions.isEmpty {
                    emptyState
                } else {
                    reviewList
                }
            }
            .navigationTitle("LV aus PDF importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if !parsedPositions.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Importieren (\(selectedCount))") { importSelected() }
                            .disabled(selectedCount == 0)
                            .tint(.orange)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                PDFDocumentPicker { url in handlePick(url: url) }
                    .ignoresSafeArea()
            }
            .alert("Nicht erkannt", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(parseError ?? "PDF konnte nicht verarbeitet werden.")
            }
            .overlay {
                if isParsing {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().scaleEffect(1.4)
                            Text(parsingHinweis).font(.subheadline)
                        }
                        .padding(28)
                        .background(.ultraThickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("PDF-LV importieren")
                        .font(.title2.bold())
                    Text("Wähle eine PDF-Datei mit einem Leistungsverzeichnis.\niMOPS erkennt Positionen automatisch.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        importQuelle = .lokal
                        showDocumentPicker = true
                    } label: {
                        Label("PDF auswählen", systemImage: "doc.badge.plus")
                            .font(.headline)
                            .padding(.horizontal, 32).padding(.vertical, 14)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        importQuelle = .mops
                        showDocumentPicker = true
                    } label: {
                        Label("Statik per Mops auswerten", systemImage: "brain.head.profile")
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Text("Mops liest Statik-/Bewehrungspläne: Mengen, Kostengruppe und Mat-Nr automatisch.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Unterstützte Formate", systemImage: "info.circle")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text("• Standard-LV, GAEB-Export, Planungsbüro-PDFs\n• Erkannt: Pos.-Nr. + Beschreibung + Menge + Einheit\n• Alle Positionen können vor dem Import bearbeitet werden\n• Eingescannte PDFs (nur Bilder) werden nicht unterstützt")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
            .padding()
        }
    }

    // MARK: - Review List

    private var reviewList: some View {
        List {
            Section {
                HStack {
                    Label("\(parsedPositions.count) erkannte Positionen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Neues PDF") {
                        parsedPositions = []
                        showDocumentPicker = true
                    }
                    .font(.caption).tint(.orange)
                }

                HStack {
                    Text("Alle auswählen").font(.subheadline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { allSelected },
                        set: { v in parsedPositions.indices.forEach { parsedPositions[$0].isSelected = v } }
                    ))
                    .labelsHidden()
                }
            } footer: {
                Text("KG wird auf 300 gesetzt und kann nach dem Import über Swipe-Bearbeiten geändert werden.")
            }

            Section("Positionen prüfen") {
                ForEach($parsedPositions) { $pos in
                    positionRow($pos)
                }
                .onDelete { idx in parsedPositions.remove(atOffsets: idx) }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func positionRow(_ pos: Binding<ParsedLVPosition>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: pos.isSelected)
                .labelsHidden()
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(pos.wrappedValue.posNr)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                    Text(pos.wrappedValue.bezeichnung)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text("\(pos.wrappedValue.menge.formatted(.number.precision(.fractionLength(0...2)))) \(pos.wrappedValue.einheit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    let conf = pos.wrappedValue.confidence
                    Image(systemName: conf > 0.8 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(conf > 0.8 ? .green : .yellow)
                    Text(conf > 0.8 ? "Sicher erkannt" : "Bitte prüfen")
                        .font(.caption2)
                        .foregroundStyle(conf > 0.8 ? .green : .secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private func parsePDF(url: URL) {
        isParsing = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Copy to temp dir while we still have security-scoped access
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: tmp)

            let positions = LVPDFImporter.extract(from: tmp)

            DispatchQueue.main.async {
                isParsing = false
                if positions.isEmpty {
                    parseError = "Keine LV-Positionen erkannt.\n\nBitte prüfe ob die PDF Texte enthält (nicht nur gescannte Bilder) und mindestens Pos.-Nr., Beschreibung, Menge und Einheit vorhanden sind."
                    showError = true
                } else {
                    parsedPositions = positions
                }
            }
        }
    }

    /// Routet die ausgewählte PDF an den lokalen Parser oder an den Mops.
    private func handlePick(url: URL) {
        switch importQuelle {
        case .lokal:
            parsingHinweis = "PDF wird analysiert ..."
            parsePDF(url: url)
        case .mops:
            parsingHinweis = "Mops liest den Plan … (kann etwas dauern)"
            parsePDFViaMops(url: url)
        }
    }

    /// Lädt die PDF an die Box (/extract-plan) und füllt die Vorschau aus dem
    /// Mops-Ergebnis (inkl. Kostengruppe + Mat-Nr aus dem abZ-Resolver).
    private func parsePDFViaMops(url: URL) {
        // Kopie ins Temp, solange der Security-Scope noch aktiv ist
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: tmp)
        do {
            try FileManager.default.copyItem(at: url, to: tmp)
        } catch {
            parseError = "PDF konnte nicht gelesen werden."
            showError = true
            return
        }
        isParsing = true
        Task {
            do {
                let data = try Data(contentsOf: tmp)
                let result = try await MopsClient().extractPlan(
                    pdf: data, filename: tmp.lastPathComponent,
                    projekt: event.eventNumber, baustelle: event.title)
                let parsed = ExtractPlanMapper.toParsed(result)
                isParsing = false
                if parsed.isEmpty {
                    parseError = "Der Mops hat keine Positionen aus dem Plan gelesen."
                    showError = true
                } else {
                    parsedPositions = parsed
                }
            } catch {
                isParsing = false
                parseError = (error as? MopsClientError)?.errorDescription ?? error.localizedDescription
                showError = true
            }
        }
    }

    private func importSelected() {
        for parsed in parsedPositions where parsed.isSelected {
            let pos = LVPosition(context: viewContext)
            pos.posNr              = parsed.posNr
            pos.bezeichnung        = parsed.bezeichnung
            pos.menge              = parsed.menge
            pos.einheit            = parsed.einheit
            pos.kostenGruppeNummer = parsed.kostenGruppe ?? "300"
            pos.artikelNummer      = parsed.artikelNummer   // Mops-Import: Mat-Nr
            pos.lieferant          = parsed.lieferant
            pos.event              = event
        }
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - PDF Document Picker

struct PDFDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = false
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let secured = url.startAccessingSecurityScopedResource()
            onPick(url)
            if secured { url.stopAccessingSecurityScopedResource() }
        }
    }
}
