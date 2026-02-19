import SwiftUI
import UniformTypeIdentifiers

/// Document Picker fuer CAD-Dateien (USDZ, OBJ, DAE).
/// Kopiert die Datei in die App-Sandbox und gibt die lokale URL zurueck.
struct CADDocumentPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Unterstuetzte Typen: USDZ + generische 3D-Formate
        var types: [UTType] = []
        if let usdz = UTType("com.pixar.universal-scene-description-mobile") {
            types.append(usdz)
        }
        if let obj = UTType("public.geometry-definition-format") {
            types.append(obj)
        }
        if let dae = UTType("org.khronos.collada.digital-asset-exchange") {
            types.append(dae)
        }
        // Fallback: alle 3D-Inhalte
        types.append(.threeDContent)

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else { return }

            // Security-Scoped Resource Zugriff
            guard sourceURL.startAccessingSecurityScopedResource() else { return }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            // In App-Sandbox kopieren
            let fileManager = FileManager.default
            let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)

            do {
                if !fileManager.fileExists(atPath: cadDir.path) {
                    try fileManager.createDirectory(at: cadDir, withIntermediateDirectories: true)
                }

                let destURL = cadDir.appendingPathComponent(sourceURL.lastPathComponent)

                // Falls gleiche Datei schon existiert, ueberschreiben
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }

                try fileManager.copyItem(at: sourceURL, to: destURL)
                onPicked(destURL)
            } catch {
                print("CAD Import Fehler: \(error)")
            }
        }
    }
}

// MARK: - Plantypen

enum PlanType: String, CaseIterable, Identifiable {
    case grundriss = "Grundriss"
    case schnitt = "Schnitt"
    case elektroplan = "Elektroplan"
    case sanitaerplan = "Sanitaerplan"
    case statik = "Statik"
    case sonstiges = "Sonstiges"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grundriss:     return "rectangle.split.3x3"
        case .schnitt:       return "scissors"
        case .elektroplan:   return "bolt.fill"
        case .sanitaerplan:  return "drop.fill"
        case .statik:        return "triangle.fill"
        case .sonstiges:     return "doc.fill"
        }
    }
}

// MARK: - Verwaltung der importierten CAD-Dateien

struct CADFileInfo: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var fileName: String
    var relativePath: String // Relativer Pfad unter Documents/CADFiles/
    var importDate: Date = Date()
    var planType: String = "Sonstiges"

    var fullURL: URL? {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docsDir.appendingPathComponent("CADFiles").appendingPathComponent(relativePath)
    }

    // Backward-compatible decoding fuer bestehende Daten ohne planType
    enum CodingKeys: String, CodingKey {
        case id, fileName, relativePath, importDate, planType
    }

    init(fileName: String, relativePath: String, planType: String = "Sonstiges") {
        self.fileName = fileName
        self.relativePath = relativePath
        self.planType = planType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fileName = try c.decode(String.self, forKey: .fileName)
        relativePath = try c.decode(String.self, forKey: .relativePath)
        importDate = try c.decode(Date.self, forKey: .importDate)
        planType = try c.decodeIfPresent(String.self, forKey: .planType) ?? "Sonstiges"
    }
}

struct CADFilesPayload: Codable {
    var files: [CADFileInfo] = []
}
