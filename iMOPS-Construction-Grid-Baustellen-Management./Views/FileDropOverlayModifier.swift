import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileDropOverlayModifier
// Wiederverwendbarer ViewModifier der ein Drop-Target mit visuellem
// Feedback (Overlay + Animation) hinzufuegt. Zeigt beim Hovern einen
// Hinweis an und ruft den onDrop-Callback mit der lokalen URL auf.

struct FileDropOverlayModifier: ViewModifier {
    let acceptedExtensions: Set<String>
    let label: String
    let icon: String
    let onFileDrop: (URL) -> Void

    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    dropOverlay
                }
            }
            .onDrop(of: [.fileURL, .item], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
    }

    private var dropOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.12))
                .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                .padding(8)

            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(acceptedExtensions.sorted().joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .allowsHitTesting(false)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        Task {
            guard let url = await FileDropHelper.copyToTemp(from: provider) else { return }
            let ext = url.pathExtension.lowercased()
            guard acceptedExtensions.isEmpty || acceptedExtensions.contains(ext) else { return }
            await MainActor.run {
                onFileDrop(url)
            }
        }
        return true
    }
}

// MARK: - View Extension

extension View {

    /// Fuegt ein Drop-Target fuer GAEB-Dateien hinzu (.x83, .x84, .xml)
    func gaebDropTarget(onDrop: @escaping (URL) -> Void) -> some View {
        modifier(FileDropOverlayModifier(
            acceptedExtensions: ["x83", "x84", "xml"],
            label: "GAEB-Datei hier ablegen",
            icon: "doc.badge.arrow.up",
            onFileDrop: onDrop
        ))
    }

    /// Fuegt ein Drop-Target fuer CAD/3D-Dateien hinzu
    func cadDropTarget(onDrop: @escaping (URL) -> Void) -> some View {
        modifier(FileDropOverlayModifier(
            acceptedExtensions: ["usdz", "usda", "usdc", "obj", "dae", "scn",
                                 "fbx", "stl", "ply", "gltf", "glb", "abc", "skp"],
            label: "3D-Datei hier ablegen",
            icon: "cube",
            onFileDrop: onDrop
        ))
    }

    /// Fuegt ein Drop-Target fuer PDF-Dateien hinzu
    func pdfDropTarget(onDrop: @escaping (URL) -> Void) -> some View {
        modifier(FileDropOverlayModifier(
            acceptedExtensions: ["pdf"],
            label: "PDF hier ablegen",
            icon: "doc.text",
            onFileDrop: onDrop
        ))
    }

    /// Fuegt ein allgemeines Drop-Target fuer alle unterstuetzten Dateien hinzu
    func universalFileDropTarget(onDrop: @escaping (URL) -> Void) -> some View {
        modifier(FileDropOverlayModifier(
            acceptedExtensions: ["x83", "x84", "xml", "pdf",
                                 "usdz", "usda", "usdc", "obj", "dae", "scn",
                                 "fbx", "stl", "ply", "gltf", "glb", "abc", "skp"],
            label: "Datei hier ablegen",
            icon: "square.and.arrow.down",
            onFileDrop: onDrop
        ))
    }
}
