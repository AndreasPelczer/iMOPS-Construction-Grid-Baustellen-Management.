import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileDropService
// Zentraler Handler fuer Drag-and-Drop von externen Dateien.
// Routet Dateien je nach Typ an den richtigen Import-Handler.

enum DroppedFileType {
    case gaeb       // .x83, .x84, .xml (GAEB)
    case cad        // .usdz, .obj, .dae, .fbx, .stl, .gltf, .glb
    case skp        // .skp (SketchUp)
    case pdf        // .pdf (LV-Import)
    case unknown

    static func detect(from url: URL) -> DroppedFileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "x83", "x84":
            return .gaeb
        case "xml":
            // XML koennte GAEB sein — wir behandeln es als GAEB im LV-Kontext
            return .gaeb
        case "skp":
            return .skp
        case "usdz", "usda", "usdc", "obj", "dae", "scn", "fbx", "stl",
             "ply", "gltf", "glb", "abc":
            return .cad
        case "pdf":
            return .pdf
        default:
            return .unknown
        }
    }
}

// Unterstuetzte UTTypes fuer Drop-Targets
enum FileDropUTTypes {
    // Alle Dateitypen die wir akzeptieren
    static let allSupported: [UTType] = [
        .xml,
        .pdf,
        .threeDContent,
        .item,
        .fileURL,
    ]

    // Nur GAEB-relevante Typen
    static let gaebTypes: [UTType] = [
        .xml,
        .item,
        .fileURL,
    ]
}

// MARK: - Drop-Hilfsfunktionen

enum FileDropHelper {

    /// Kopiert eine gedroppte Datei in ein temporaeres Verzeichnis und gibt die lokale URL zurueck.
    static func copyToTemp(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            // Zuerst versuchen wir fileURL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        let localURL = copyToTempDir(from: url)
                        continuation.resume(returning: localURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
                return
            }

            // Fallback: item als URL
            if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.item.identifier) { item, _ in
                    if let url = item as? URL {
                        let localURL = copyToTempDir(from: url)
                        continuation.resume(returning: localURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
                return
            }

            continuation.resume(returning: nil)
        }
    }

    /// Kopiert eine Datei ins temp-Verzeichnis (Security-Scoped-Zugriff wird beachtet)
    private static func copyToTempDir(from sourceURL: URL) -> URL? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let destURL = tempDir.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            return nil
        }
    }
}
