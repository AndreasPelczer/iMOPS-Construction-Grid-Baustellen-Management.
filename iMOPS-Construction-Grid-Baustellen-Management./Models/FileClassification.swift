import Foundation

// MARK: - FileCategory
// MVP-Klassen fuer die KI-Klassifikation. Phase 5d kann erweitern.

enum FileCategory: String, CaseIterable, Codable {
    case gaebLV      = "GAEB-LV"
    case pdfDocument = "PDF-Dokument"
    case cadPlan     = "CAD-Plan"
    case photo       = "Foto"
    case excelData   = "Excel-Mengen"
    case unknown     = "Unbekannt"
}

// MARK: - FileClassification

struct FileClassification: Codable {
    let category: String
    let confidence: Double
    let reasoning: String?
}

enum ClassificationSource {
    case ai
    case fallback
}

// MARK: - Classify Request

struct ClassifyRequest: Codable {
    let filename: String
    let fileExtension: String
    let sizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case filename
        case fileExtension = "extension"
        case sizeBytes = "size_bytes"
    }
}

// MARK: - Extension-based Fallback

extension FileCategory {
    static func fromExtension(_ ext: String) -> FileCategory {
        switch ext.lowercased() {
        case "x83", "x84", "x86":             return .gaebLV
        case "pdf":                            return .pdfDocument
        case "skp", "obj", "usdz", "usda",
             "usdc", "dae", "scn", "fbx",
             "stl", "ply", "gltf", "glb",
             "abc":                            return .cadPlan
        case "jpg", "jpeg", "png", "heic",
             "heif", "tiff", "bmp":            return .photo
        case "xlsx", "xls", "csv":             return .excelData
        default:                               return .unknown
        }
    }

    static func fallbackClassification(for url: URL) -> FileClassification {
        let cat = fromExtension(url.pathExtension)
        return FileClassification(
            category: cat.rawValue,
            confidence: 1.0,
            reasoning: nil
        )
    }
}
