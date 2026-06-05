import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BuildIQ")

// MARK: - BuildIQService
/// Schickt erkannten Text (OCR) an die Mops-Box (POST /classify-material) und
/// erhält eine DIN-276-Kostengruppe zurück.
///
/// Läuft jetzt über die **lokale Box** statt Gemini-Cloud → Lieferschein-Daten
/// (oft mit Bauherr-Name/Adresse) bleiben im Heimnetz. Das öffentliche Interface
/// `analyzeText(_:) -> BuildIQResult` bleibt unverändert (View/OCR/Zuweisung gleich).
/// Nutzt MopsConfig.host + MopsClientError aus MopsClient.swift (eine Konfiguration).
class BuildIQService {

    static let endpoint = "/classify-material"

    private let urlSession: URLSession

    init(urlSession: URLSession? = nil) {
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            // Klassifikation läuft CPU-only auf der Box → großzügiger Timeout.
            config.timeoutIntervalForRequest = MopsConfig.requestTimeoutSeconds
            config.timeoutIntervalForResource = MopsConfig.requestTimeoutSeconds
            self.urlSession = URLSession(configuration: config)
        }
    }

    private struct MaterialRequest: Encodable { let text: String }

    /// Analysiert erkannten OCR-Text und gibt eine DIN-276-Zuweisung zurück.
    func analyzeText(_ text: String) async throws -> BuildIQResult {
        guard let url = URL(string: MopsConfig.host + Self.endpoint) else {
            throw MopsClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MaterialRequest(text: text))

        logger.info("BuildIQ classify-material: \(text.prefix(60))…")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                logger.error("classify-material Timeout nach \(MopsConfig.requestTimeoutSeconds)s")
                throw MopsClientError.timeout
            }
            logger.error("classify-material nicht erreichbar: \(error.localizedDescription)")
            throw MopsClientError.serverOffline
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<keine Antwort>"
            logger.error("classify-material HTTP \(http.statusCode): \(body)")
            throw MopsClientError.httpError(statusCode: http.statusCode, body: body)
        }

        return try JSONDecoder().decode(BuildIQResult.self, from: data)
    }
}
