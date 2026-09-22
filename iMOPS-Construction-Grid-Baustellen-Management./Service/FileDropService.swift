import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - FileDropService
// Zentraler Handler fuer Drag-and-Drop von externen Dateien.
// Routet Dateien je nach Typ an den richtigen Import-Handler.

/// Was für eine Datei ist das — und was macht der Mops damit?
///
/// 🔴 Ergänzt am 22.09.2026. Der Erkenner kannte **kein DXF, kein DWG, kein IFC,
/// kein JSON und kein GAEB 90 (.d83/.d84)** — also ausgerechnet die Formate, die
/// Raphi schickt. Gemessen: `.dxf` kommt in sechs Dateien der App vor, im Erkenner
/// stand es nicht.
///
/// Und der Drop selbst (`FileDropOverlayModifier`) war gebaut, getestet und
/// **nirgends eingehängt** — dasselbe Muster wie `istStartbar` am 21.09.
enum DroppedFileType {
    case gaeb       // .x83, .x84, .x86, .xml — GAEB DA XML
    case gaeb90     // .d83, .d84, .d86 — GAEB 90, das ältere Format
    case dxf        // .dxf — Zeichnung mit Layern, daraus kommen Mengen
    case dwg        // .dwg — AutoCAD, muss erst umgewandelt werden
    case ifc        // .ifc — Bauwerksmodell
    case cad        // .usdz, .obj, .stl, .glb … — 3D zum Ansehen
    case skp        // .skp — SketchUp
    case pdf        // .pdf
    case photo      // .jpg, .png, .heic
    case excel      // .xlsx, .xls, .csv
    case json       // .json — LV oder Stammdaten
    case unknown

    static func detect(from url: URL) -> DroppedFileType {
        switch url.pathExtension.lowercased() {
        case "x83", "x84", "x86", "xml":          return .gaeb
        case "d83", "d84", "d86":                 return .gaeb90
        case "dxf":                               return .dxf
        case "dwg":                               return .dwg
        case "ifc", "ifcxml", "ifczip":           return .ifc
        case "skp":                               return .skp
        case "usdz", "usda", "usdc", "obj", "dae", "scn", "fbx", "stl",
             "ply", "gltf", "glb", "abc":         return .cad
        case "pdf":                               return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "bmp":
                                                  return .photo
        case "xlsx", "xls", "csv":                return .excel
        case "json":                              return .json
        default:                                  return .unknown
        }
    }

    /// Wohin die Datei gehört — in Andreas' Worten, nicht in Dateiendungen.
    var wasDerMopsDamitMacht: String {
        switch self {
        case .gaeb:    return "Leistungsverzeichnis einlesen — Positionen, Mengen, Einheiten"
        case .gaeb90:  return "Leistungsverzeichnis einlesen (älteres GAEB-90-Format)"
        case .dxf:     return "Zeichnung lesen — Wände, Türen, Gelände, Aushubmengen"
        case .dwg:     return "AutoCAD-Zeichnung — muss erst auf der Box umgewandelt werden"
        case .ifc:     return "Bauwerksmodell — Bauteile und Mengen aus den Objektnamen"
        case .cad:     return "3D-Modell ansehen"
        case .skp:     return "SketchUp-Modell — wird zu USDZ umgewandelt"
        case .pdf:     return "Unterlage auswerten — LV, Statik, Bodengutachten, B-Plan"
        case .photo:   return "Foto ablegen — Mangel, Bautagesbericht, Lieferschein"
        case .excel:   return "Tabelle einlesen — Mengen, Material, Preise"
        case .json:    return "Leistungsverzeichnis oder Stammdaten einlesen"
        case .unknown: return "Der Mops kennt dieses Format nicht"
        }
    }

    /// Braucht es eine Baustelle, um die Datei einzulesen?
    var brauchtBaustelle: Bool {
        switch self {
        case .excel, .json, .unknown: return false
        default:                      return true
        }
    }
}

extension DroppedFileType {
    var displayName: String {
        switch self {
        case .gaeb:    return "GAEB-Datei"
        case .gaeb90:  return "GAEB 90"
        case .dxf:     return "DXF-Zeichnung"
        case .dwg:     return "DWG-Zeichnung"
        case .ifc:     return "IFC-Modell"
        case .json:    return "JSON-Datei"
        case .cad:     return "3D-Modell"
        case .skp:     return "SketchUp-Datei"
        case .pdf:     return "PDF-Dokument"
        case .photo:   return "Foto"
        case .excel:   return "Excel-Tabelle"
        case .unknown: return "Unbekannter Dateityp"
        }
    }

    var iconName: String {
        switch self {
        case .gaeb:    return "doc.badge.arrow.up"
        case .gaeb90:  return "doc.badge.arrow.up"
        case .dxf:     return "scribble.variable"
        case .dwg:     return "scribble.variable"
        case .ifc:     return "building.2"
        case .json:    return "curlybraces"
        case .cad:     return "cube"
        case .skp:     return "cube.transparent"
        case .pdf:     return "doc.text"
        case .photo:   return "photo"
        case .excel:   return "tablecells"
        case .unknown: return "questionmark.folder"
        }
    }

    var iconColor: Color {
        switch self {
        case .gaeb:    return .orange
        case .gaeb90:  return .orange
        case .dxf:     return .blue
        case .dwg:     return .blue
        case .ifc:     return .purple
        case .json:    return .orange
        case .cad:     return .green
        case .skp:     return .blue
        case .pdf:     return .red
        case .photo:   return .purple
        case .excel:   return .green
        case .unknown: return .gray
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

    /// Kopiert eine URL direkt ins temp-Verzeichnis (dropDestination API / Mac).
    static func copyToTemp(from url: URL) -> URL? {
        copyToTempDir(from: url)
    }

    /// Kopiert eine gedroppte Datei in ein temporaeres Verzeichnis und gibt die lokale URL zurueck.
    static func copyToTemp(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            // Zuerst versuchen wir fileURL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    // Mac: item ist direkt eine URL
                    if let url = item as? URL {
                        let localURL = copyToTempDir(from: url)
                        continuation.resume(returning: localURL)
                    // iOS: item kommt als Data-Repraesentation
                    } else if let data = item as? Data,
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
