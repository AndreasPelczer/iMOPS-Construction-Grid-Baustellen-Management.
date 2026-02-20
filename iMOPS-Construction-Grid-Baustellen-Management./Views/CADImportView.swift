import SwiftUI
import UniformTypeIdentifiers

/// Document Picker fuer CAD-Dateien (USDZ, OBJ, DAE, FBX, STL, glTF).
/// Kopiert die Datei in die App-Sandbox und gibt die lokale URL zurueck.
/// Formate die SceneKit nicht direkt lesen kann werden per Server zu USDZ konvertiert.
struct CADDocumentPicker: UIViewControllerRepresentable {
    /// Callback: liefert die lokale URL (bei Konvertierung: die USDZ-URL)
    let onPicked: (URL) -> Void
    /// Callback: wird bei Dateien aufgerufen, die Server-Konvertierung brauchen
    var onServerConvert: ((URL) -> Void)?
    /// Callback: wird bei SKP-Dateien aufgerufen (nicht direkt unterstuetzt).
    /// Liefert die lokale URL der kopierten SKP-Datei.
    var onSKPPicked: ((URL?) -> Void)?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Unterstuetzte Typen: USDZ, OBJ, DAE + weitere 3D-Formate
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
        // Fallback: alle 3D-Inhalte + beliebige Dateien (damit FBX, STL, glTF, SKP erkannt werden)
        types.append(.threeDContent)
        types.append(.item)

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onServerConvert: onServerConvert, onSKPPicked: onSKPPicked, cadDir: Self.cadDirectory)
    }

    /// App-Sandbox Verzeichnis fuer CAD-Dateien
    private static var cadDirectory: URL {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docsDir.appendingPathComponent("CADFiles", isDirectory: true)
    }

    /// Formate die SceneKit direkt laden kann (keine Konvertierung noetig)
    private static let nativeFormats: Set<String> = ["usdz", "usda", "usdc", "obj", "dae", "scn", "abc"]

    /// Formate die lokal auf dem Geraet konvertiert werden koennen (ModelIO)
    private static let localConvertFormats: Set<String> = ["stl", "ply"]

    /// Formate die per Server zu USDZ konvertiert werden (Blender)
    private static let convertFormats: Set<String> = ["fbx", "gltf", "glb"]

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let onServerConvert: ((URL) -> Void)?
        let onSKPPicked: ((URL?) -> Void)?
        let cadDir: URL

        init(onPicked: @escaping (URL) -> Void, onServerConvert: ((URL) -> Void)?, onSKPPicked: ((URL?) -> Void)?, cadDir: URL) {
            self.onPicked = onPicked
            self.onServerConvert = onServerConvert
            self.onSKPPicked = onSKPPicked
            self.cadDir = cadDir
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let sourceURL = urls.first else { return }

            // Security-Scoped Resource Zugriff
            guard sourceURL.startAccessingSecurityScopedResource() else { return }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let ext = sourceURL.pathExtension.lowercased()

            // SKP-Dateien: In Sandbox kopieren und Callback mit URL aufrufen
            if ext == "skp" {
                let localURL = copySKPToSandbox(sourceURL: sourceURL)
                onSKPPicked?(localURL)
                return
            }

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

                // Formate die lokal konvertiert werden koennen (STL, PLY)
                if CADDocumentPicker.localConvertFormats.contains(ext) {
                    do {
                        let usdzURL = try SKPConversionService.shared.convertLocally(fileURL: destURL)
                        onPicked(usdzURL)
                    } catch {
                        // Fallback: Server-Konvertierung versuchen
                        if let handler = onServerConvert {
                            handler(destURL)
                        }
                    }
                }
                // Formate die Server-Konvertierung brauchen (FBX, glTF)
                else if CADDocumentPicker.convertFormats.contains(ext), let handler = onServerConvert {
                    handler(destURL)
                } else {
                    // Native Formate direkt anzeigen (USDZ, OBJ, DAE)
                    onPicked(destURL)
                }
            } catch {
                print("CAD Import Fehler: \(error)")
            }
        }

        /// Kopiert eine SKP-Datei in die App-Sandbox, damit sie spaeter
        /// per UIDocumentInteractionController an SketchUp uebergeben werden kann.
        private func copySKPToSandbox(sourceURL: URL) -> URL? {
            let fileManager = FileManager.default
            do {
                if !fileManager.fileExists(atPath: cadDir.path) {
                    try fileManager.createDirectory(at: cadDir, withIntermediateDirectories: true)
                }
                let destURL = cadDir.appendingPathComponent(sourceURL.lastPathComponent)
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destURL)
                return destURL
            } catch {
                print("SKP Kopie-Fehler: \(error)")
                return nil
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
