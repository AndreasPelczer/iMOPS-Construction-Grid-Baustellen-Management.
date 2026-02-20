import Foundation
import ModelIO
import SceneKit
import SceneKit.ModelIO

/// Service fuer die 3D-Datei-zu-USDZ-Konvertierung.
///
/// Konvertiert 3D-Dateien in USDZ fuer den CAD-Viewer.
/// Unterstuetzt zwei Modi:
///   1. **Lokal (On-Device):** STL, OBJ via ModelIO -> USDZ (kein Server noetig)
///   2. **Server:** FBX, glTF/glB via Blender-Server -> USDZ
///
/// Ablauf (Server-Modus):
///   1. App waehlt 3D-Datei aus (Document Picker)
///   2. SKPConversionService.convert() laedt die Datei zum Server hoch
///   3. Server konvertiert zu USDZ (via Blender headless)
///   4. Server gibt USDZ zurueck
///   5. App speichert USDZ lokal und zeigt sie im CAD-Viewer an
///
/// Konfiguration: Server-URL in UserDefaults unter "imops_server_url"
/// Default: http://localhost:8080
class SKPConversionService {

    /// Formate die ModelIO auf dem Geraet lesen kann (kein Server noetig)
    static let localConvertFormats: Set<String> = ["stl", "obj", "ply"]

    static let shared = SKPConversionService()

    /// UserDefaults-Key fuer die Server-URL
    static let serverURLKey = "imops_server_url"

    /// Standard-Server-URL (lokal fuer Entwicklung)
    static let defaultServerURL = "http://localhost:8080"

    /// Aktuelle Server-URL (konfigurierbar via Settings)
    var serverURL: String {
        get {
            UserDefaults.standard.string(forKey: Self.serverURLKey)
                ?? Self.defaultServerURL
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.serverURLKey)
        }
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600  // 10 Min fuer grosse Dateien
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    // MARK: - Hauptfunktion: 3D-Datei -> USDZ konvertieren

    /// Konvertiert eine lokale 3D-Datei serverseitig zu USDZ.
    ///
    /// - Parameter fileURL: Lokaler Pfad zur 3D-Datei (in der App-Sandbox)
    /// - Returns: Lokaler Pfad zur konvertierten .usdz-Datei
    /// - Throws: ConversionError bei Netzwerk-/Server-Fehlern
    func convert(fileURL: URL) async throws -> URL {
        let endpoint = URL(string: "\(serverURL)/api/convert")!

        // Multipart-Request aufbauen
        let boundary = "iMOPS-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        // Request senden
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversionError.invalidResponse
        }

        // Fehlerbehandlung
        if httpResponse.statusCode != 200 {
            if let errorJSON = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw ConversionError.serverError(errorJSON.error)
            }
            throw ConversionError.httpError(httpResponse.statusCode)
        }

        // USDZ-Datei lokal speichern
        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)

        if !fileManager.fileExists(atPath: cadDir.path) {
            try fileManager.createDirectory(at: cadDir, withIntermediateDirectories: true)
        }

        // Dateiname: Original-Name mit .usdz Endung
        let usdzName = (fileURL.deletingPathExtension().lastPathComponent) + ".usdz"
        let usdzURL = cadDir.appendingPathComponent(usdzName)

        // Falls gleiche Datei existiert, ueberschreiben
        if fileManager.fileExists(atPath: usdzURL.path) {
            try fileManager.removeItem(at: usdzURL)
        }

        try data.write(to: usdzURL)
        return usdzURL
    }

    // MARK: - Lokale On-Device Konvertierung (ModelIO)

    /// Prueft ob eine Datei lokal (ohne Server) konvertiert werden kann.
    func canConvertLocally(fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return Self.localConvertFormats.contains(ext)
    }

    /// Konvertiert eine 3D-Datei lokal auf dem Geraet zu USDZ via ModelIO.
    /// Unterstuetzt STL, OBJ, PLY.
    /// - Parameter fileURL: Lokaler Pfad zur 3D-Datei
    /// - Returns: Lokaler Pfad zur konvertierten .usdz-Datei
    /// - Throws: ConversionError bei Fehlern
    func convertLocally(fileURL: URL) throws -> URL {
        // MDLAsset laden
        let asset = MDLAsset(url: fileURL)
        guard asset.count > 0 else {
            throw ConversionError.serverError(
                "Datei konnte nicht geladen werden (keine 3D-Objekte gefunden)"
            )
        }

        // Ausgabepfad vorbereiten
        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)

        if !fileManager.fileExists(atPath: cadDir.path) {
            try fileManager.createDirectory(at: cadDir, withIntermediateDirectories: true)
        }

        let usdzName = fileURL.deletingPathExtension().lastPathComponent + ".usdz"
        let usdzURL = cadDir.appendingPathComponent(usdzName)

        // Falls gleiche Datei existiert, ueberschreiben
        if fileManager.fileExists(atPath: usdzURL.path) {
            try fileManager.removeItem(at: usdzURL)
        }

        // USDZ exportieren via ModelIO
        if MDLAsset.canExportFileExtension("usdz") {
            do {
                try asset.export(to: usdzURL)
                if fileManager.fileExists(atPath: usdzURL.path) {
                    return usdzURL
                }
            } catch {
                // Fallback auf SCNScene-Methode
            }
        }

        // Fallback: Ueber SCNScene -> write(to:) als .usdz
        let scene = SCNScene(mdlAsset: asset)
        let success = scene.write(
            to: usdzURL,
            options: nil,
            delegate: nil,
            progressHandler: nil
        )

        if success {
            return usdzURL
        }

        throw ConversionError.serverError(
            "Lokale Konvertierung fehlgeschlagen. "
            + "Bitte das Format OBJ oder DAE verwenden, "
            + "oder einen Konvertierungsserver konfigurieren."
        )
    }

    // MARK: - Server Health Check

    /// Prueft ob der Konvertierungsserver erreichbar ist.
    func checkHealth() async -> ServerHealth? {
        guard let url = URL(string: "\(serverURL)/api/health") else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(ServerHealth.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Fehlertypen

    enum ConversionError: LocalizedError {
        case invalidResponse
        case httpError(Int)
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Ungueltige Server-Antwort"
            case .httpError(let code):
                return "Server-Fehler (HTTP \(code))"
            case .serverError(let msg):
                return "Konvertierung fehlgeschlagen: \(msg)"
            }
        }
    }

    struct ServerError: Decodable {
        let error: String
    }

    struct ServerHealth: Decodable {
        let status: String
        let blenderAvailable: Bool

        enum CodingKeys: String, CodingKey {
            case status
            case blenderAvailable = "blender_available"
        }
    }
}

// MARK: - Data Extension fuer Multipart

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
