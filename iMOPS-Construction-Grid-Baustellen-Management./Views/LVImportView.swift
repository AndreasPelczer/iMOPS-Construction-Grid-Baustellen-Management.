import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - LV Import View

struct LVImportView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDocumentPicker = false
    @State private var showJSONPicker = false
    @State private var parsedPositions: [ParsedLVPosition] = []
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var showError = false
    @State private var importQuelle: ImportQuelle = .lokal
    @State private var parsingHinweis = "PDF wird analysiert ..."
    
    // NEU: Hier merken wir uns die Metadaten der geladenen Datei für CoreData
    @State private var geladenerDateiName: String? = nil
    @State private var geladenerDateiPfad: String? = nil

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
                PDFDocumentPicker { urls in handlePicks(urls: urls) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showJSONPicker) {
                JSONDocumentPicker { urls in importJSONFiles(urls: urls) }
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
                    Text("Wähle eine oder mehrere PDF-Dateien mit einem Leistungsverzeichnis.\niMOPS erkennt Positionen automatisch und führt sie zusammen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        importQuelle = .lokal
                        showDocumentPicker = true
                    } label: {
                        Label("PDFs auswählen", systemImage: "doc.badge.plus")
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

                    Button {
                        showJSONPicker = true
                    } label: {
                        Label("LV aus JSON-Datei", systemImage: "curlybraces.square")
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Text("Mops liest Statik-/Bewehrungspläne: Mengen, Kostengruppe und Mat-Nr automatisch.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Label("Unterstützte Formate", systemImage: "info.circle")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text("• Standard-LV, GAEB-Export, Planungsbüro-PDFs\n• Erkannt: Pos.-Nr. + Beschreibung + Menge + Einheit\n• Alle Positionen können vor dem Import bearbeitet werden\n• Eingescannte PDFs (nur Bilder) werden nicht unterstützt")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
                    Button("PDF hinzufügen") {
                        // hängt an die bereits erkannten Positionen an (kein Zurücksetzen)
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

    /// Liest lokal aus einer oder mehreren PDFs und HÄNGT die Positionen an
    /// (erlaubt schrittweises Zusammenführen mehrerer LV-Dateien).
    private func parsePDFs(urls: [URL]) {
        isParsing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var collected: [ParsedLVPosition] = []
            for url in urls {
                collected.append(contentsOf: LVPDFImporter.extract(from: url))
            }

            DispatchQueue.main.async {
                isParsing = false
                if collected.isEmpty {
                    parseError = "Keine LV-Positionen erkannt.\n\nBitte prüfe ob die PDF(s) Texte enthalten (nicht nur gescannte Bilder) und mindestens Pos.-Nr., Beschreibung, Menge und Einheit vorhanden sind."
                    showError = true
                } else {
                    parsedPositions.append(contentsOf: collected)
                }
            }
        }
    }

    /// Routet die gewählten PDFs an den lokalen Parser oder an den Mops.
    private func handlePicks(urls: [URL]) {
        guard !urls.isEmpty else { return }
        // Fallback-Metadaten (nur genutzt, falls eine Position keine eigene Herkunft trägt)
        geladenerDateiName = urls.first?.lastPathComponent
        geladenerDateiPfad = urls.first?.absoluteString

        let mehrere = urls.count > 1
        switch importQuelle {
        case .lokal:
            parsingHinweis = mehrere ? "\(urls.count) PDFs werden analysiert …" : "PDF wird analysiert …"
            parsePDFs(urls: urls)
        case .mops:
            parsingHinweis = mehrere ? "Mops liest \(urls.count) Pläne … (kann dauern)" : "Mops liest den Plan … (kann etwas dauern)"
            parsePDFsViaMops(urls: urls)
        }
    }

    /// Schickt mehrere PDFs nacheinander an den Mops (jeder Call ist CPU-teuer) und
    /// hängt alle erkannten Positionen an. Herkunft pro Position wird nachgetragen.
    private func parsePDFsViaMops(urls: [URL]) {
        isParsing = true
        Task {
            var collected: [ParsedLVPosition] = []
            var letzterFehler: String?
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let result = try await MopsClient().extractPlan(
                        pdf: data, filename: url.lastPathComponent,
                        projekt: event.eventNumber, baustelle: event.title)
                    var parsed = ExtractPlanMapper.toParsed(result)
                    for i in parsed.indices where parsed[i].quellDateiName == nil {
                        parsed[i].quellDateiName = url.lastPathComponent
                        parsed[i].quellDateiURL  = url
                    }
                    collected.append(contentsOf: parsed)
                } catch {
                    letzterFehler = (error as? MopsClientError)?.errorDescription ?? error.localizedDescription
                }
            }
            isParsing = false
            if collected.isEmpty {
                parseError = letzterFehler ?? "Der Mops hat keine Positionen aus den Plänen gelesen."
                showError = true
            } else {
                parsedPositions.append(contentsOf: collected)
            }
        }
    }

    /// Lädt eine oder mehrere lokale JSON-Dateien im ExtractPlanResult-Format
    /// (extern per Vision erzeugt, z.B. Town-&-Country-LVs) und hängt die Positionen
    /// an. Dekodiert lokal statt den Mops zu rufen — sonst identisch zum Mops-Weg.
    private func importJSONFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        geladenerDateiName = urls.first?.lastPathComponent
        geladenerDateiPfad = urls.first?.absoluteString
        parsingHinweis = urls.count > 1 ? "\(urls.count) JSON-Dateien werden gelesen …" : "JSON wird gelesen …"
        isParsing = true
        Task {
            var collected: [ParsedLVPosition] = []
            var letzterFehler: String?
            for url in urls {
                do {
                    let data = try Data(contentsOf: url)
                    let result = try JSONDecoder().decode(ExtractPlanResult.self, from: data)
                    var parsed = ExtractPlanMapper.toParsed(result)
                    for i in parsed.indices where parsed[i].quellDateiName == nil {
                        parsed[i].quellDateiName = url.lastPathComponent
                        parsed[i].quellDateiURL  = url
                    }
                    collected.append(contentsOf: parsed)
                } catch {
                    letzterFehler = "‚\(url.lastPathComponent)‘ ist keine gültige LV-JSON "
                                  + "(erwartet ExtractPlanResult mit lv_positionen): \(error.localizedDescription)"
                }
            }
            isParsing = false
            if collected.isEmpty {
                parseError = letzterFehler ?? "Keine Positionen in der JSON gefunden."
                showError = true
            } else {
                parsedPositions.append(contentsOf: collected)
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
            pos.artikelNummer      = parsed.artikelNummer
            pos.lieferant          = parsed.lieferant
            pos.event              = event
            
            // Herkunft PRO Position (Merge mehrerer PDFs) — mit Fallback auf die
            // zuletzt geladene Datei, falls eine Position keine eigene Quelle trägt.
            if let dateiName = parsed.quellDateiName ?? geladenerDateiName {
                pos.setValue(dateiName, forKey: "dokuName")
            }
            if let dateiPfad = parsed.quellDateiURL?.absoluteString ?? geladenerDateiPfad {
                pos.setValue(dateiPfad, forKey: "dokuPath")
            }
        }
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - PDF Document Picker

struct PDFDocumentPicker: UIViewControllerRepresentable {
    /// Liefert lokale tmp-Kopien der gewählten PDFs (eine oder mehrere).
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = true
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Jede Datei UNTER dem Security-Scope in den tmp-Ordner kopieren — sonst
            // ist sie nach dem Schließen des Pickers nicht mehr lesbar. So bleiben auch
            // mehrere Dateien gleichzeitig gültig (Scope lässt sich nicht async halten).
            let fm = FileManager.default
            var localCopies: [URL] = []
            for url in urls {
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                let tmp = fm.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? fm.removeItem(at: tmp)
                do {
                    try fm.copyItem(at: url, to: tmp)
                    localCopies.append(tmp)
                } catch {
                    // einzelne, nicht kopierbare Datei überspringen statt alles abzubrechen
                }
            }
            onPick(localCopies)
        }
    }
}

// MARK: - JSON Document Picker

/// Wie `PDFDocumentPicker`, aber für extern erzeugte LV-JSONs (ExtractPlanResult).
struct JSONDocumentPicker: UIViewControllerRepresentable {
    /// Liefert lokale tmp-Kopien der gewählten JSON-Dateien (eine oder mehrere).
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // UTType.json ist Standard; Fallback über die Endung, falls das System den
        // Typ für eine Datei nicht meldet.
        let jsonTypes = [UTType.json, UTType(filenameExtension: "json")].compactMap { $0 }
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: jsonTypes)
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = true
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let fm = FileManager.default
            var localCopies: [URL] = []
            for url in urls {
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                let tmp = fm.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? fm.removeItem(at: tmp)
                do {
                    try fm.copyItem(at: url, to: tmp)
                    localCopies.append(tmp)
                } catch {
                    // einzelne, nicht kopierbare Datei überspringen statt alles abzubrechen
                }
            }
            onPick(localCopies)
        }
    }
}
