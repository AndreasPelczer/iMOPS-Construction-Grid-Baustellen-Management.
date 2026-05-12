import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - GAEB Import View

struct GAEBImportView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDocumentPicker = false
    @State private var importResult: GAEBImportResult?
    @State private var items: [GAEBImportItem] = []
    @State private var isParsing = false
    @State private var parseError: String?
    @State private var showError = false

    private var selectedCount: Int { items.filter { $0.isSelected }.count }
    private var allSelected: Bool  { items.allSatisfy { $0.isSelected } }
    private var isX84: Bool        { importResult?.dp == 84 }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    reviewList
                }
            }
            .navigationTitle("GAEB importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isX84 ? "Angebot importieren (\(selectedCount))" : "LV importieren (\(selectedCount))") {
                            importSelected()
                        }
                        .disabled(selectedCount == 0)
                        .tint(.orange)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                GAEBDocumentPicker { url in parsefile(url: url) }
                    .ignoresSafeArea()
            }
            .alert("Nicht erkannt", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(parseError ?? "Die Datei konnte nicht verarbeitet werden.")
            }
            .overlay {
                if isParsing {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().scaleEffect(1.4)
                            Text("GAEB wird analysiert …").font(.subheadline)
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
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("GAEB-Datei importieren")
                        .font(.title2.bold())
                    Text("Importiere eine X83-Datei (Angebotsaufforderung) um das\nLeistungsverzeichnis zu übernehmen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Datei wählen (.x83 / .xml)", systemImage: "doc.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 28).padding(.vertical, 14)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Format-Hinweise", systemImage: "info.circle")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text("• Unterstützt: GAEB DA XML 3.2 und 3.3\n• Phasen: X83 (Angebotsaufforderung) und X84 (Angebot)\n• Dateien als .x83, .x84 oder .xml speichern\n• Encoding: UTF-8 und Windows-1252 werden erkannt\n• Nicht unterstützt: GAEB 90 (.d83/.d84 Binärformat)")
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
            // Header info
            Section {
                if let result = importResult {
                    LabeledContent("Projekt", value: result.projectName.isEmpty ? "–" : result.projectName)
                    LabeledContent("GAEB", value: "DA XML \(result.gaebVersion) · DP\(result.dp)")
                    if !result.ownerName.isEmpty {
                        LabeledContent("Auftraggeber", value: result.ownerName)
                    }
                    if isX84 {
                        Label("Angebot enthält Einheitspreise — werden in Angebotsvergleich übernommen",
                              systemImage: "tag.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                HStack {
                    Label("\(items.count) Positionen erkannt", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Neue Datei") {
                        items = []; importResult = nil
                        showDocumentPicker = true
                    }
                    .font(.caption).tint(.orange)
                }

                HStack {
                    Text("Alle auswählen").font(.subheadline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { allSelected },
                        set: { v in items.indices.forEach { items[$0].isSelected = v } }
                    ))
                    .labelsHidden()
                }
            } footer: {
                Text("Positionen werden KG \(items.first?.guessedKG ?? "300") zugewiesen (auto-erkannt, danach bearbeitbar).")
            }

            // Grouped by KG
            let grouped = Dictionary(grouping: items, by: { $0.guessedKG })
                .sorted { $0.key < $1.key }
            ForEach(grouped, id: \.key) { kg, kgItems in
                Section("KG \(kg) – \(kgName(kg))") {
                    ForEach(kgItems.indices, id: \.self) { idx in
                        if let globalIdx = items.firstIndex(where: { $0.id == kgItems[idx].id }) {
                            itemRow(binding: $items[globalIdx])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func itemRow(binding item: Binding<GAEBImportItem>) -> some View {
        let v = item.wrappedValue
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: item.isSelected)
                .labelsHidden()
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if v.isAlternative {
                        Text("ALT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    Text(v.posNr)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(v.isAlternative ? .blue : .orange)
                    Text(v.kurztext)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text("\(v.menge.formatted(.number.precision(.fractionLength(0...3)))) \(v.einheit)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if let up = v.unitPrice, up > 0 {
                        Text("·").foregroundStyle(.secondary)
                        Text(up, format: .currency(code: "EUR"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.green)
                        Text("EP")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !v.groupTitle.isEmpty {
                        Text("· \(v.groupTitle)")
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func parsefile(url: URL) {
        isParsing = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Copy to temp while security-scoped access is open
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: tmp)

            do {
                let result = try GAEBImporter.parse(url: tmp)
                DispatchQueue.main.async {
                    isParsing = false
                    importResult = result
                    items = result.items
                }
            } catch {
                DispatchQueue.main.async {
                    isParsing = false
                    parseError = error.localizedDescription
                    showError  = true
                }
            }
        }
    }

    private func importSelected() {
        let store = AngebotsStore.shared
        for item in items where item.isSelected {
            let pos = LVPosition(context: viewContext)
            pos.posNr              = item.posNr
            pos.bezeichnung        = item.kurztext
            pos.menge              = item.menge
            pos.einheit            = item.einheit
            pos.kostenGruppeNummer = item.guessedKG
            pos.event              = event

            // If X84: store unit price in AngebotsStore as "Auftraggeber"-offer
            if let up = item.unitPrice, up > 0, isX84 {
                let posID  = pos.objectID.uriRepresentation().absoluteString
                let angebot = Angebot(lieferant: importResult?.ownerName.isEmpty == false
                                     ? importResult!.ownerName : "GAEB-Import",
                                     einzelpreis: up)
                store.upsert(angebot, for: posID)
            }
        }
        try? viewContext.save()
        dismiss()
    }

    private func kgName(_ kg: String) -> String {
        switch kg {
        case "100": return "Grundstück"
        case "200": return "Herrichten & Erschließen"
        case "300": return "Baukonstruktionen"
        case "310": return "Baugrube"
        case "320": return "Gründung"
        case "330": return "Außenwände"
        case "340": return "Innenwände"
        case "350": return "Decken"
        case "360": return "Dächer"
        case "370": return "Infrastruktur"
        case "380": return "Fenster & Türen"
        case "390": return "Sonstige Baukonstruktion"
        case "400": return "Technische Anlagen"
        case "410": return "Abwasser, Wasser, Gas"
        case "420": return "Wärmeversorgung"
        case "430": return "Lufttechnische Anlagen"
        case "440": return "Starkstrom"
        case "450": return "Fernmelde- & IT-Anlagen"
        case "500": return "Außenanlagen"
        case "600": return "Ausstattung"
        case "700": return "Baunebenkosten"
        default: return "Sonstige"
        }
    }
}

// MARK: - Document Picker

struct GAEBDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Accept .xml + .data (broad fallback catches .x83/.x84 on most systems)
        var types: [UTType] = [.xml]
        if let x83 = UTType(filenameExtension: "x83") { types.append(x83) }
        if let x84 = UTType(filenameExtension: "x84") { types.append(x84) }
        types.append(.data)
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types)
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = false
        return vc
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let secured = url.startAccessingSecurityScopedResource()
            onPick(url)
            if secured { url.stopAccessingSecurityScopedResource() }
        }
    }
}
