import SwiftUI
import UniformTypeIdentifiers

/// Document Picker fuer CAD- und Plan-Dateien (USDZ, OBJ, DAE, FBX, STL, glTF, SKP sowie PDF, DXF, DWG, IFC, Excel und Word).
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
        var types: [UTType] = []
        
        // 1. Native 3D-Formate von Apple
        if let usdz = UTType("com.pixar.universal-scene-description-mobile") { types.append(usdz) }
        if let obj = UTType("public.geometry-definition-format") { types.append(obj) }
        if let dae = UTType("org.khronos.collada.digital-asset-exchange") { types.append(dae) }
        
        // 2. Dokumenten- & Büro-Klassiker
        types.append(.pdf)          // PDFs für 2D-Pläne
        types.append(.spreadsheet)  // Excel-Dateien (.xlsx, .xls)
        types.append(.text)         // Word-Dateien & Text-Protokolle (.docx, .doc, .txt)
        types.append(.image)        // Fotos/Scans von Plänen (.png, .jpeg)
        
        // 3. Erweiterte CAD- & BIM-Formate per File-Extension registrieren
        let customExtensions = ["dxf", "dwg", "ifc", "step", "stp", "x83", "d83", "x84", "d84"]
        for ext in customExtensions {
            if let customType = UTType(filenameExtension: ext) {
                types.append(customType)
            }
        }
        
        // Fallbacks: Generischer 3D-Inhalt und allgemeine Elemente (damit fbx, stl, gltf, skp sicher ziehen)
        types.append(.threeDContent)
        types.append(.item)

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = true   // Mehrere Pläne/PDFs in einem Rutsch auswählen
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

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let onServerConvert: ((URL) -> Void)?
        let onSKPPicked: ((URL?) -> Void)?
        let cadDir: URL

        // Formate direkt im Coordinator definiert, um Scope-Fehler zu vermeiden
        private let nativeFormats: Set<String> = [
            "usdz", "usda", "usdc", "obj", "dae", "scn", "abc",
            "pdf", "xlsx", "xls", "docx", "doc", "txt", "png", "jpg", "jpeg"
        ]
        private let localConvertFormats: Set<String> = ["stl", "ply"]
        private let convertFormats: Set<String> = ["fbx", "gltf", "glb", "dwg", "dxf", "ifc"]

        init(onPicked: @escaping (URL) -> Void, onServerConvert: ((URL) -> Void)?, onSKPPicked: ((URL?) -> Void)?, cadDir: URL) {
            self.onPicked = onPicked
            self.onServerConvert = onServerConvert
            self.onSKPPicked = onSKPPicked
            self.cadDir = cadDir
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Mehrfachauswahl: jede gewählte Datei einzeln verarbeiten.
            for url in urls {
                verarbeiteDatei(url)
            }
        }

        /// Verarbeitet EINE gewählte Datei (kopieren + je nach Format weiterreichen).
        private func verarbeiteDatei(_ sourceURL: URL) {
            // Security-Scoped Resource Zugriff
            guard sourceURL.startAccessingSecurityScopedResource() else { return }
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            let ext = sourceURL.pathExtension.lowercased()

            // SKP-Dateien gesondert behandeln
            if ext == "skp" {
                let localURL = copySKPToSandbox(sourceURL: sourceURL)
                onSKPPicked?(localURL)
                return
            }

            let fileManager = FileManager.default

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

                // 1. Formate die lokal konvertiert werden koennen (STL, PLY)
                if localConvertFormats.contains(ext) {
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
                // 2. Formate die Server-Konvertierung brauchen (FBX, glTF, DWG, DXF, IFC)
                else if convertFormats.contains(ext), let handler = onServerConvert {
                    handler(destURL)
                }
                // 3. Native Formate direkt zurückgeben (PDF, Office, Bilder, USDZ)
                else {
                    onPicked(destURL)
                }
            } catch {
                print("Datei Import Fehler: \(error)")
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
