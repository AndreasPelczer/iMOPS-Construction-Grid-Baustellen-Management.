import SwiftUI

struct FileInspectionSheet: View {
    @Environment(ImportedFileHandler.self) private var fileHandler
    @Environment(\.dismiss) private var dismiss

    @State private var gaebResult: GAEBImportResult?
    @State private var parseError: String?
    @State private var isParsing = false

    private var fileURL: URL? { fileHandler.lastImportedFileURL }
    private var fileName: String { fileHandler.importedFileName }
    private var fileType: DroppedFileType {
        guard let url = fileURL else { return .unknown }
        return DroppedFileType.detect(from: url)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)
                    headerSection
                    detailSection
                    actionSection
                    Spacer(minLength: 40)
                }
                .padding()
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
        } else if fileType == .unknown {
            Label("Dieser Dateityp wird von iMOPS nicht unterstützt.",
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
        case 86:  return "Aufmaß (X86)"
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
                primaryButton("In SketchUp Web öffnen", icon: "safari", color: .blue) {
                    fileHandler.pendingAction = .openSKP
                    dismiss()
                }

            case .cad:
                primaryButton("3D-Viewer öffnen", icon: "cube", color: .green) {
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
        guard let url = fileURL, fileType == .gaeb else { return }
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
