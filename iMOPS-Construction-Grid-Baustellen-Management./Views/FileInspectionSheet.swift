import SwiftUI

struct FileInspectionSheet: View {
    @Environment(ImportedFileHandler.self) private var fileHandler
    @Environment(\.dismiss) private var dismiss

    @State private var gaebResult: GAEBImportResult?
    @State private var parseError: String?
    @State private var isParsing = false

    @State private var classification: FileClassification?
    @State private var classificationSource: ClassificationSource = .fallback
    @State private var isClassifying = false

    private let mopsClient = MopsClient()

    private var fileURL: URL? { fileHandler.lastImportedFileURL }
    private var fileName: String { fileHandler.importedFileName }
    private var fileType: DroppedFileType {
        guard let url = fileURL else { return .unknown }
        return DroppedFileType.detect(from: url)
    }

    private var classifiedCategory: FileCategory {
        guard let cat = classification?.category else { return .unknown }
        return FileCategory(rawValue: cat) ?? .unknown
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if classificationSource == .fallback && classification != nil {
                        offlineBanner
                    }
                    VStack(spacing: 28) {
                        Spacer(minLength: 20)
                        headerSection
                        classificationSection
                        detailSection
                        actionSection
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Datei-Inspektion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task { await analyzeFile() }
        }
    }

    // MARK: - Offline Banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Mops nicht erreichbar — vereinfachte Klassifikation")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.yellow.opacity(0.15))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: fileType.iconName)
                .font(.system(size: 56))
                .foregroundStyle(fileType.iconColor)
            Text(fileName)
                .font(.headline)
            Text(fileType.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - KI Classification

    @ViewBuilder
    private var classificationSection: some View {
        if isClassifying {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Mops analysiert …")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let cls = classification {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: classificationSource == .ai ? "brain.head.profile" : "doc.badge.gearshape")
                        .foregroundStyle(classificationSource == .ai ? .purple : .secondary)
                    Text(cls.category)
                        .font(.subheadline.bold())
                    if classificationSource == .ai {
                        Text("(\(Int(cls.confidence * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let reasoning = cls.reasoning, !reasoning.isEmpty, classificationSource == .ai {
                    Text(reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if cls.confidence < 0.7 && classificationSource == .ai {
                    Label("Unsicher — bitte pruefen", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Details

    @ViewBuilder
    private var detailSection: some View {
        if isParsing {
            ProgressView("Datei wird analysiert …")
        } else if let result = gaebResult {
            gaebDetailView(result)
        } else if let error = parseError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        } else if fileType == .unknown && classifiedCategory == .unknown {
            Label("Dieser Dateityp wird von iMOPS nicht unterstuetzt.",
                  systemImage: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func gaebDetailView(_ result: GAEBImportResult) -> some View {
        VStack(spacing: 8) {
            Label("GAEB erkannt", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            if !result.projectName.isEmpty {
                Text(result.projectName).font(.subheadline.bold())
            }
            HStack(spacing: 8) {
                Text("DA XML \(result.gaebVersion)")
                Text("·")
                Text(dpLabel(result.dp))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("\(result.items.count) Positionen")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(.orange)

            if !result.ownerName.isEmpty {
                Text("AG: \(result.ownerName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dpLabel(_ dp: Int) -> String {
        switch dp {
        case 84:  return "Angebot (X84)"
        case 86:  return "Aufmass (X86)"
        default:  return "Ausschreibung (X83)"
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 12) {
            switch fileType {
            case .gaeb:
                primaryButton("In LV importieren", icon: "square.and.arrow.down", color: .orange) {
                    fileHandler.pendingAction = .importGAEB
                    dismiss()
                }
                .disabled(gaebResult == nil)

            case .skp:
                primaryButton("In SketchUp Web oeffnen", icon: "safari", color: .blue) {
                    fileHandler.pendingAction = .openSKP
                    dismiss()
                }

            case .cad:
                primaryButton("3D-Viewer oeffnen", icon: "cube", color: .green) {
                    fileHandler.pendingAction = .openCADViewer
                    dismiss()
                }

            case .pdf, .unknown:
                EmptyView()
            }

            if let url = fileURL {
                Button {
                    ExternalAppLauncher.shared.openInExternalApp(fileURL: url)
                } label: {
                    Label("Teilen / Andere App", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }

    private func primaryButton(_ title: String, icon: String, color: Color,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    // MARK: - Analysis

    private func analyzeFile() async {
        guard let url = fileURL else { return }

        async let classifyTask: () = classifyWithMops(url: url)
        async let gaebTask: () = parseGAEBIfNeeded(url: url)
        _ = await (classifyTask, gaebTask)
    }

    private func classifyWithMops(url: URL) async {
        isClassifying = true
        let isOnline = await mopsClient.checkHealth()

        if isOnline {
            let size: Int64 = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            do {
                let result = try await mopsClient.classifyFile(
                    name: url.lastPathComponent,
                    ext: url.pathExtension.lowercased(),
                    sizeBytes: size
                )
                classification = result
                classificationSource = .ai
            } catch {
                classification = FileCategory.fallbackClassification(for: url)
                classificationSource = .fallback
            }
        } else {
            classification = FileCategory.fallbackClassification(for: url)
            classificationSource = .fallback
        }
        isClassifying = false
    }

    private func parseGAEBIfNeeded(url: URL) async {
        guard fileType == .gaeb else { return }
        isParsing = true
        do {
            let result = try await Task.detached {
                try GAEBImporter.parse(url: url)
            }.value
            gaebResult = result
        } catch {
            parseError = error.localizedDescription
        }
        isParsing = false
    }
}
